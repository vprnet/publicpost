require 'digest/md5'

# Job that crawls the website of a Municipality.
class CrawlMunicipality < Worker

  sidekiq_options queue: "low"
  sidekiq_options :retry => false

  # Crawl the website of the Municipality with the given slug.
  #
  # @param [String] arg The Municipality slug
  def run(arg)
    municipality = Municipality.find_by_slug!(arg)

    # Determine the scope of the crawl, in terms of page depth, new documents,
    # and duration:
    #
    # (1) If this is an initial crawl:
    #
    #     - Respect the soft page depth limit
    #     - Cap the maximum new documents to a limit based upon population
    #     - Cap the crawl duration to a limit a limit based upon population
    #
    # (2) If this is an incremental crawl:
    #
    #     - Allow the page depth to exceed the soft page depth limit but respect
    #       the hard page depth limit. If a page that is at or above the soft
    #       page depth limit contains a majority of new links, crawl the page
    #     - Cap the maximum new documents to a limit based upon population
    #     - Cap the crawl duration to a limit based upon population
    #

    is_first_crawl = municipality.last_crawl_date.nil?
    population     = municipality.population

    # Determine the new document and crawl duration limits
    case population
      when 0..1000
        max_crawl_docs    = 100
        max_crawl_minutes = 60
      when 1000..5000
        max_crawl_docs    = 200
        max_crawl_minutes = 60
      when 5000..10000
        max_crawl_docs    = 300
        max_crawl_minutes = 120
      when 10000..50000
        max_crawl_docs    = 1000
        max_crawl_minutes = 120
      when 50000..100000
        max_crawl_docs    = 2000
        max_crawl_minutes = 180
      else
        max_crawl_docs    = 3000
        max_crawl_minutes = 240
    end

    # Calculate the time after which the crawl must be terminated
    max_crawl_date = Time.now + max_crawl_minutes.minutes

    # If this is an incremental crawl, reduce the document limit by a factor of 10
    max_crawl_docs = max_crawl_docs/10 unless is_first_crawl

    # Begin the crawl
    current_crawl_date = Time.now
    current_crawl_docs = 0

    Anemone.crawl(municipality.website.split, {
        :accept_cookies => municipality.website_accept_cookies?,
        :obey_robots_txt => true,
        :discard_page_details => true,
        :delay => Constants::ANEMONE_DELAY,
        :user_agent => Constants::ANEMONE_USER_AGENT,
        :linkable_domains => municipality.website_linkable_domains,
        :max_queue_size => Constants::ANEMONE_MAX_QUEUE_SIZE,
        :connect_timeout => Constants::ANEMONE_CONNECT_TIMEOUT,
        :read_timeout => Constants::ANEMONE_READ_TIMEOUT,
        :depth_limit => Constants::ANEMONE_HARD_DEPTH_LIMIT,
        :threads => Constants::ANEMONE_THREADS }) do |anemone|

      # Skip error pages, 404 pages, etc., and any municipality-specific links
      skip_links_regexp = Constants::ANEMONE_SKIP_LINKS
      skip_links = municipality.website_skip_links
      unless skip_links.nil?
        skip_links_regexp = Array.new(Constants::ANEMONE_SKIP_LINKS)
        skip_links.split.each do |regexp|
          skip_links_regexp << Regexp.new(regexp)
        end
      end
      unless skip_links_regexp.empty?
        anemone.skip_links_like(skip_links_regexp)
      end

      # Eliminate query params from links, if necessary
      strip_params_regexp = []
      strip_params = municipality.website_strip_params
      unless strip_params.nil?
        strip_params.split.each do |regexp|
          strip_params_regexp << Regexp.new(regexp)
        end
      end
      unless strip_params_regexp.empty?
        anemone.transform_links do |link|
          transform_link(link, strip_params_regexp)
        end
      end

      # Limit the crawl scope
      anemone.focus_crawl do |page|
        links = nil

        # Potentially limit the crawl depth for HTML pages
        if page.html?

          # We only need to limit the crawl depth when we hit the soft limit
          page_depth = page.depth
          if page_depth >= Constants::ANEMONE_SOFT_DEPTH_LIMIT

            # If we hit the hard limit, do not proceed
            if page_depth >= Constants::ANEMONE_HARD_DEPTH_LIMIT
              links = []
              # TODO: Note this page in the municipality
              logger.warn "!!! Black hole detected (#{municipality.slug}) :: (#{page.url})"

              # If this is an initial crawl, do not proceed
            elsif is_first_crawl
              links = []

              # Only proceed if the majority of the page's links are new
            else
              # Create an array of GUIDs for each of the page's links
              links = page.links
              guids = []
              links.each do |link|
                content_url = transform_link(link, strip_params_regexp).to_s
                guids << Digest::MD5.hexdigest(content_url)
              end

              # Determine the number of links that already exist
              old_count = 0
              links.each do |link|
                content_url = transform_link(link, strip_params_regexp).to_s
                guid        = Digest::MD5.hexdigest(content_url)

                exists = false
                if Document.unscoped.exists?(:guid => guid)
                  old_count += 1
                  exists = true
                end
              end

              # Only proceed if more than half the links are new
              all_count = links.size
              new_count = all_count - old_count
              if new_count > 0 && (new_count < 2 || (new_count < all_count/2))
                links = []
                logger.info "!!! Gray hole detected (#{municipality.slug}) :: (#{page.url}) :: (#{page_depth}) :: (#{new_count}/#{all_count})"              end
            end
          end
        end

        if links.nil?
          # Default behavior
          links = page.links
        end
        links
      end

      # Process crawled pages
      anemone.on_every_page do |page|

        # We only want to process HTTP_OK (200)
        if page.code == 200

          content_url  = page.url.to_s
          content_type = page.content_type
          unless content_type.nil?
            content_type = content_type.split[0]
            unless content_type.nil?
              content_type = content_type.gsub(';', '')
            end
          end

          guid = Digest::MD5.hexdigest(content_url)

          last_modified = page.headers["last-modified"].nil? ? nil : page.headers["last-modified"].first
          description   = "(#{content_url}) :: (#{content_type}) :: (#{last_modified})"

          # Four cases:
          #
          # (1) The Document exists and has been processed
          # (2) The Document does not exist
          # (3) The Document exists and has not been processed
          # (4) The Document has been deleted
          #
          # In case (1), nothing to do
          # In case (2), save and process the Document
          # In case (3), process the Document if it was created within the past week
          # In case (4), nothing to do
          #
          # We will optimize for the common case (1).

          if Document.exists?(:guid => guid) # :state => Document::PROCESSED
            # case (1)
            logger.info "--- Not saved #{description}"
          else
            document = Document.unscoped.where(:guid => guid).select(%w(id guid state created_at deleted_at)).first
            if document.nil?
              # case (2)

              # Determine if the content is consumable
              is_text = Document.is_text?(content_type)
              unless is_text || !Document.is_binary?(content_type)
                # If the content type is a binary type, check the "content-disposition" header for
                # well-known parseable binary file extensions. For example:
                #
                # "content-disposition"=>["attachment; filename=\"minutes.pdf\""]
                content_disposition = page.headers['content-disposition']
                unless content_disposition.nil? || content_disposition.empty?
                  content_disposition = content_disposition[0]
                  if content_disposition =~ /attachment; filename="(.+)\.([^\."]+)"/
                    file_extension = $2.downcase
                    is_text = Document::PARSEABLE_FILE_EXTENSIONS.include?(file_extension)
                  end
                end
              end

              # Create a new Document, if necessary
              if is_text
                document = municipality.documents.build
                document.guid = guid
                document.content_url = content_url
                document.content_type = content_type
                document.last_modified = last_modified
                document.state = Document::DISCOVERED

                document.save!
                logger.info "+++ Saved #{description}"
                current_crawl_docs += 1
                Workflow.start_process_document(document.id)
              end
            elsif document.deleted_at.nil?
              if document.state == Document::DISCOVERED
                # case (3)
                if document.created_at >= 7.days.ago
                  logger.info "+++ Reprocessing #{description}"
                  Workflow.start_process_document(document.id)
                else
                  logger.info "+++ Skipping unprocessed #{description}"
                end
              end
            else
              # case (4)
              logger.info "+++ Skipping deleted #{description}"
            end
          end
        end

        # Terminate the crawl if we've hit the new document or crawl duration limit
        if current_crawl_docs >= max_crawl_docs || Time.now >= max_crawl_date
          duration_minutes = ((Time.now - current_crawl_date) / 60).to_i
          logger.info "--- Terminating crawl of #{arg} after #{current_crawl_docs}/#{max_crawl_docs} document(s) and #{duration_minutes}/#{max_crawl_minutes} minutes(s)"
          anemone.stop
        end
      end
    end

    # Save the last successful crawl time
    municipality.last_crawl_date = current_crawl_date
    municipality.save!
  end

  #
  # Return a transformed URI for the given link by stripping any query
  # parameters that match the given array of regular expressions.
  #
  def transform_link(link, strip_params_regexp)
    query = link.query

    unless query.nil? || strip_params_regexp.empty?
      # Create an array of query parameters
      delimiter = query.include?('&amp;') ? '&amp;' : '&'
      params    = query.split(delimiter)

      # Reject any query parameters that match a website's strip regexp
      new_params = params.reject do |q|
        p = q.split('=').first
        strip_params_regexp.any? { |regexp|  p =~ regexp }
      end

      # If a query parameter was stripped, create a new link
      if new_params.size < params.size
        base_uri = link.to_s.split('?').first
        query    = new_params.join(delimiter)
        if query.size == 0
          link = URI(base_uri)
        else
          link = URI("#{base_uri}?#{new_params.join(delimiter)}")
        end
      end
    end

    link
  end
end
