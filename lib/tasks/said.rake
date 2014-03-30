require 'csv'
require 'nokogiri'
require 'open-uri'
require 'set'

namespace :said do

  desc 'Update document entities.'
  task update_document_entities: :environment do
    Document.unscoped.where("extracted_text is not null").order("created_at desc").find_in_batches do |group|
      group.each do |document|
        UpdateDocumentEntities.perform_async(document.id, nil)
      end
    end
  end

  desc 'Make Topic Model for the given Municipality.'
  task :make_topic_model, [:municipality_slug] => [:environment] do |t,args|
    slug = args[:municipality_slug]
    muni = Municipality.find_by_slug(slug)
    CSV.open("#{slug}-documents.csv", "wb") do |csv|
      muni.documents.each do |d|
        unless d.extracted_text.nil?
          text = d.extracted_text
          text = text.downcase
          text = safe_squeeze(text)
          people_to_remove = []
          unless d.people.nil?
            d.people.each do |p|
              people_to_remove << p.name.downcase
            end
          end
          text = text.gsub(/\b(#{ people_to_remove.join('|') })\b/, '')
          text = text.gsub(/\b(#{ Constants::STOPWORDS.join('|') })\b/, '')
          text = text.gsub(/\b(#{ Constants::POPULAR_LAST_NAMES.join('|') })\b/, '')
          text = text.gsub(/\b(#{ Constants::POPULAR_MALE_FIRST_NAMES.join('|') })\b/, '')
          text = text.gsub(/\b(#{ Constants::POPULAR_FEMALE_FIRST_NAMES.join('|') })\b/, '')
          text = text.gsub(/[^a-zA-Z]/, ' ')
          # TODO: state names
          # TODO: city names
          csv << [d.id, text]
        end
      end
    end
  end

  #
  # Municipality workflow
  #

  desc 'Make Municipalities for a given state. Only do this once.'
  task :make_cities, [:state_abbreviation, :state_name] => [:environment] do |t,args|
    state_abbreviation = args[:state_abbreviation]
    state_name = args[:state_name]
    make_municipalities_for_state([state_abbreviation, state_name])
  end

  desc 'Load California city websites from Wikipedia entries'
  task load_california_websites: :environment do
    def get_official_website(city_name, url)
      doc = Nokogiri::HTML(open(url))
      doc.xpath('//div[4]/table[1]/tr').each do |row|
        if row.to_s.match(/Website/i)
          city_website = row.xpath('td//a').map { |link| link['href'] }[0]
          return city_website
        end
      end
    end

    url = "http://en.wikipedia.org/wiki/List_of_cities_and_towns_in_California"
    doc = Nokogiri::HTML(open(url))

    doc.xpath('//table[3]/tr/th').each do |row|
      wiki_link = row.xpath('a').map { |link| link['href'] }[0]
      city_name = row.xpath('a').text
      unless city_name.nil? || city_name.length == 0
        url = "http://en.wikipedia.org#{wiki_link}"
        url = get_official_website(city_name, url)
        slug = Municipality.create_slug(city_name, "CA")
        puts ">>>> Updating #{slug}"
        muni = Municipality.find_by_slug(slug)
        unless muni.nil?
          muni.website = url
          muni.save!
        end
      end
    end
  end

  desc 'Update database with municipality data'
  task update: :environment do
    update_municipalities
  end

  desc "Crawl municipality websites. Provide a slug like 'watertown-town-ma' to crawl a single website."
  task :crawl_municipalities, [:slug] => [:environment] do |t,args|
    slug = args[:slug]

    if slug.nil?
      puts 'No municipality was provided, crawling them all...'
      municipalities = Municipality.select('slug').all(conditions: 'website is not null')
    else
      municipalities = [ Municipality.find_by_slug!(slug) ]
    end

    municipalities.each do |municipality|
      Workflow.start_crawl_municipality(municipality.slug)
    end
  end

  desc "Clear a municipality's documents"
  task :clear_municipality, [:slug] => [:environment] do |t,args|
    slug = args[:slug]

    if slug.nil?
      puts 'No municipality was provided!'
    else
      municipality = Municipality.find_by_slug!(slug)

      # For large document sets, it is necessary to destroy one-by-one:
      #municipality.documents.clear

      # Must include create_at, updated_at, and deleted_at attributes because of paper_trail and paranoia gems
      municipality.documents.select(['id', 'created_at', 'updated_at', 'deleted_at']).each do |d| d.destroy! end
    end
  end

  desc "Touch a municipality's documents"
  task :touch_municipality, [:slug] => [:environment] do |t,args|
    slug = args[:slug]

    if slug.nil?
      puts 'No municipality was provided!'
    else
      municipality = Municipality.find_by_slug!(slug)

      # Must include create_at and updated_at attribute because of paper_trail gem
      municipality.documents.select(['id', 'created_at', 'updated_at', 'deleted_at']).each do |d| d.touch end
    end
  end

  #
  # Model analysis and cleanup
  #

  desc "Destroy orphaned documents"
  task destroy_orphaned_documents: :environment do
    # Find all municipality identifiers referenced by documents
    identifiers = Set.new
    Document.all(:select => 'distinct(municipality_id)').each do |d|
      identifiers.add(d.municipality_id)
    end

    # Remove all valid municipality identifiers
    Municipality.select('id').each do |m|
      identifiers.delete(m.id)
    end

    count = 0
    identifiers.each do |id|
      clause = id.nil? ? 'is null' : "= #{id}"

      # Must include create_at and updated_at attribute because of paper_trail gem
      Document.where("municipality_id #{clause}").select(['id', 'created_at', 'updated_at', 'deleted_at']).each do |d|
        d.destroy!
        count += 1
      end
    end

    puts "Destroyed #{count} orphaned documents"
  end

  desc "Destroy a municipality's skipped documents"
  task :destroy_skipped_documents, [:slug] => [:environment] do |t,args|
    slug = args[:slug]

    if slug.nil?
      puts 'No municipality was provided!'
    else
      count = 0
      municipality = Municipality.find_by_slug!(slug)

      # Must include create_at and updated_at attribute because of paper_trail gem
      municipality.documents.select(['id', 'created_at', 'updated_at', 'deleted_at', 'content_url']).each do |d|
        if Constants::ANEMONE_SKIP_LINKS.any? { |pattern| d.content_url =~ pattern }
          # TODO
          # d.destroy!
          puts "Destroying: #{d.content_url}"
          count += 1
        end
      end

      puts "Destroyed #{count} skipped documents"
    end
  end

  desc "Normalize a municipality's document content URLs"
  task :normalize_document_content_urls, [:slug] => [:environment] do |t,args|
    slug = args[:slug]

    if slug.nil?
      puts 'No municipality was provided!'
    else
      count = 0
      municipality = Municipality.find_by_slug!(slug)
      municipality.documents.select(['id', 'created_at', 'updated_at', 'deleted_at', 'content_url']).each do |d|
        # Normalize the URL using the Addressable GEM, which more closely conforms to URI-related RFCs than URI does
        url        = Addressable::URI.normalized_encode(d.content_url, Addressable::URI)
        url_string = url.to_s

        query = url.query
        unless query.nil?
          # Normalize the query string, alphabetizing query parameters and dealing with duplicates. Unfortunately, there
          # isn't a standard that defines how duplicate parameters should be handled:
          #
          # http://stackoverflow.com/questions/1746507/authoritative-position-of-duplicate-http-get-query-key
          #
          # Therefore, choose the most common approach:
          #
          # https://www.owasp.org/images/b/ba/AppsecEU09_CarettoniDiPaola_v0.8.pdf

          query_values = Hash.new
          query.split('&').each do |pair|
            pair  = pair.split('=')
            key   = pair[0]
            value = pair[1]

            if !query_values.has_key?(key)
              query_values[key] = value
            end
          end
          query_values = query_values.sort

          # It would be ideal to simply set the query_values property of the URI here; unfortunately, this will result in
          # escaped characters being potentially doubly escaped. The workaround is to assembly the full query string.
          remain = query_values.size
          query  = ''
          query_values.each do |pair|
            key   = pair[0]
            value = pair[1]

            query << "#{key}=#{value}"
            unless (remain = remain - 1) == 0
              query << '&'
            end
          end

          url.query = query
        end

        if url.to_s != url_string
          # TODO
          #d.content_rul = url.to_s
          puts "Normalized: #{url_string} => #{url}"
          count += 1
        end
      end

      puts "Normalized #{count} documents"
    end
  end

  desc "Run the likely date processing on all documents in a municipality"
  task :bulk_update_likely_dates, [:slug, :save_change] => [:environment] do |t,args|
    slug = args[:slug]
    save_change = args[:save_change] == 'true'

    if slug.nil?
      puts 'No municipality was provided!'
    else
      # # Taken from here on December 9th, 2012
      # # https://docs.google.com/spreadsheet/ccc?key=0Aq_2MzT25yU2dDJ6ZEpvQ29vUUFpM0VyMjczZWZORXc#gid=7"
      # towns_with_good_dates = [
      #     "arlington-vt",
      #     "barnet-vt",
      #     "arre-vt",
      #     "bennington-vt",
      #     "benson-vt",
      #     "bethel-vt",
      #     "bolton-vt",
      #     "bradford-vt",
      #     "brattleboro-vt",
      #     "brighton-vt",
      #     "bristol-vt",
      #     "brookline-vt",
      #     "burke-vt",
      #     "cabot-vt",
      #     "calais-vt",
      #     "cambridge-vt",
      #     "charlotte-vt",
      #     "chelsea-vt",
      #     "chester-vt",
      #     "cornwall-vt",
      #     "craftsbury-vt",
      #     "dorset-vt",
      #     "dummerston-vt",
      #     "duxbury-vt",
      #     "elmore-vt",
      #     "essex-vt",
      #     "fairfield-vt",
      #     "fairlee-vt",
      #     "fayston-vt",
      #     "ferrisburgh-vt",
      #     "franklin-vt",
      #     "georgia-vt",
      #     "glover-vt",
      #     "greensboro-vt",
      #     "hartland-vt",
      #     "hinesburg-vt",
      #     "hyde-park-vt",
      #     "jay-vt",
      #     "killington-vt",
      #     "lincoln-vt",
      #     "londonderry-vt",
      #     "ludlow-vt",
      #     "lyndon-vt",
      #     "marlboro-vt",
      #     "marshfield-vt",
      #     "middlebury-vt",
      #     "montgomery-vt",
      #     "montpelier-vt",
      #     "moretown-vt",
      #     "morristown-vt",
      #     "morth-hero-vt",
      #     "northfield-vt",
      #     "norwich-vt",
      #     "panton-vt",
      #     "pawlet-vt",
      #     "pomfret-vt",
      #     "proctor-vt",
      #     "putney-vt",
      #     "rockingham-vt",
      #     "roxbury-vt",
      #     "shaftsbury-vt",
      #     "sharon-vt",
      #     "shoreham-vt",
      #     "south-burlington-vt",
      #     "stamford-vt",
      #     "stratton-vt",
      #     "thetford-vt",
      #     "townshend-vt",
      #     "tunbridge-vt",
      #     "underhill-vt",
      #     "vergennes-vt",
      #     "waitsfield-vt",
      #     "wallingford-vt",
      #     "west-windsor-vt",
      #     "westford-vt",
      #     "weston-vt",
      #     "williamstown-vt",
      #     "wilmington-vt",
      #     "worcester-vt"
      # ]

      muni = Municipality.find_by_slug(slug)
      document_count = muni.documents.count
      updated_count  = 0

      puts ">>> Processing #{document_count} documents"

      # For every document in the municipality
      count = 0
      muni.documents.find_each do |doc|
        count += 1
        puts ">>> Processing document (#{count} of #{document_count})"

        # If the document doesn't have a date or the date we
        # do have is very old and likely incorrect, try to find one again
        if (doc.likely_date.nil? || doc.likely_date < 50.years.ago.to_datetime) ||
           (!doc.versions.last.nil? && doc.versions.last.ip.nil?)

          old_date = doc.likely_date
          new_date = doc.find_likely_dates
          doc.likely_date = new_date

          # Save the document if we changed the date
          if doc.changed?
            puts "+++ Updated :: document: #{doc.guid} - old_date: #{old_date} - new_date: #{new_date} - classification: #{doc.classification}"
            if save_change
              doc.save!
            end
            updated_count += 1
          end
        end
      end

      puts "<<< Finished processing documents (#{updated_count} updated)"
    end
  end

  #
  # Send Alerts
  #
  desc "Send search alerts"
  task :send_search_alerts => [:environment] do |t, args|
    SearchAlert.send_alerts
  end

  #
  # Reporting
  #

  desc "Send a daily report of how many documents we found today"
  task :send_report => [:environment] do |t, args|

    documents = Document.past_day
    text = "
      Hi,

      There were (#{documents.size}) documents found in the past 24 hours.\n
      Document classifications:
      (#{documents.where(:classification => "agenda").size}) Agendas
      (#{documents.where(:classification => "ballot").size}) Ballots
      (#{documents.where(:classification => "bid").size}) Bids
      (#{documents.where(:classification => "budget").size}) Budgets
      (#{documents.where(:classification => "charter").size}) Charters
      (#{documents.where(:classification => "debt_authorization").size}) Debt Authorization
      (#{documents.where(:classification => "minutes").size}) Minutes
      (#{documents.where(:classification => "notice").size}) Notices
      (#{documents.where(:classification => "ordinance").size}) Ordinances
      (#{documents.where(:classification => "permit").size}) Permits
      (#{documents.where(:classification => "plan").size}) Plans
      (#{documents.where(:classification => "is_public_hearing").size}) Public Hearings
      (#{documents.where(:classification => "report").size}) Reports
      (#{documents.where(:classification => "schedule").size}) Schedules
      (#{documents.where(:classification => "zoning_map").size}) Zoning Maps
      Document types:\n
      (#{documents.where(:content_type => "application/pdf").size}) PDF
      (#{documents.where(:content_type => "text/html").size}) HTML
      (#{documents.where(:content_type => "application/msword").size}) Word

      Thanks,
      Your Report Robot
    "
    subject_error = "ERROR: " unless documents.size > 0
    subject = "#{subject_error} Daily crawl document report"

    email_data = {
        "from"          => "FILL_ME_IN",
        "to"            => "FILL_ME_IN",
        "subject"       => subject,
        "text"          => text
    }

    http_client = HTTPClient.new
    http_client.set_auth(Constants::MAILGUN_URL, 'api', Constants::MAILGUN_API_KEY)
    http_client.post(Constants::MAILGUN_URL, email_data)
  end

  desc "Send the weekly report of how many documents we found"
  task :send_weekly_report => [:environment] do |t, args|

    documents = Document.past_week
    text = "
      Hi,

      There were (#{documents.size}) documents found in the past week.\n
      Document classifications:
      (#{documents.where(:classification => "agenda").size}) Agendas
      (#{documents.where(:classification => "ballot").size}) Ballots
      (#{documents.where(:classification => "bid").size}) Bids
      (#{documents.where(:classification => "budget").size}) Budgets
      (#{documents.where(:classification => "charter").size}) Charters
      (#{documents.where(:classification => "debt_authorization").size}) Debt Authorization
      (#{documents.where(:classification => "minutes").size}) Minutes
      (#{documents.where(:classification => "notice").size}) Notices
      (#{documents.where(:classification => "ordinance").size}) Ordinances
      (#{documents.where(:classification => "permit").size}) Permits
      (#{documents.where(:classification => "plan").size}) Plans
      (#{documents.where(:classification => "is_public_hearing").size}) Public Hearings
      (#{documents.where(:classification => "report").size}) Reports
      (#{documents.where(:classification => "schedule").size}) Schedules
      (#{documents.where(:classification => "zoning_map").size}) Zoning Maps
      (#{documents.where(:classification => "unclassified").size}) Unclassified

      Document types:\n
      (#{documents.where(:content_type => "application/pdf").size}) PDF
      (#{documents.where(:content_type => "text/html").size}) HTML
      (#{documents.where(:content_type => "application/msword").size}) Word

      Thanks,
      Your Report Robot
    "
    subject_error = "ERROR: " unless documents.size > 0
    subject = "#{subject_error} Weekly crawl report"

    email_data = {
        "from"          => "FILL_ME_IN",
        "to"            => "FILL_ME_IN",
        "subject"       => subject,
        "text"          => text
    }

    http_client = HTTPClient.new
    http_client.set_auth(Constants::MAILGUN_URL, 'api', Constants::MAILGUN_API_KEY)
    http_client.post(Constants::MAILGUN_URL, email_data)
  end

  #
  # Monitoring
  #

  desc 'Look for dead websites or those that have not provided docs in a while.'
  task website_health_report: :environment do
    http_client = HTTPClient.new
    http_client.connect_timeout = Constants::DEFAULT_HTTP_TIMEOUT
    sites_to_check = []
    municipalities = Municipality.where('website is not null').find_each do |m|
      puts "Checking #{m.full_name}"
      m.website.split.each do |w|
        begin
          response = http_client.head(w, :follow_redirect => true)
          if HTTP::Status.successful?(response.code)
            #puts "    >>>> (#{response.code}) :: #{w}"
          else
            sites_to_check << [response.code, m.slug, w]
            puts "!!!! ERROR: Unresponsive website: (#{response.code}) :: #{m.slug} :: #{w}"
          end
        rescue
          ## Do nothing
        end
      end
    end
    if sites_to_check.length > 0
      text = "Website health report: \n"
      sites_to_check.each do |s|
        line_item = "(#{s[0]}) :: #{s[1]} :: #{s[2]}\n"
        text << line_item
      end
      subject = "INFO: Website health report."

      email_data = {
          "from"          => "FILL_ME_IN",
          "to"            => "FILL_ME_IN",
          "subject"       => subject,
          "text"          => text
      }
      http_client.set_auth(Constants::MAILGUN_URL, 'api', Constants::MAILGUN_API_KEY)
      http_client.post(Constants::MAILGUN_URL, email_data)
    end
  end

  #
  # Helper tasks
  #

  desc "Determine if the given URL would be skipped according to the configured skip links regular expressions."
  task :is_skipped, [:url] => [:environment] do |t,args|
    url = args[:url]

    if url.nil?
      puts 'No URL was provided.'
    else
      match = nil
      index = 0
      Constants::ANEMONE_SKIP_LINKS.each do |pattern|
        if (url =~ pattern)
          match = pattern
          break
        end
        index += 1
      end
      if (match.nil?)
        puts "false"
      else
        puts "true #{match}:#{index}"
      end
    end
  end

  #
  # Helper functions
  #

  # Populate all Municipality data.
  def make_municipalities
    Municipality.delete_all

    # STATES hash constant from environment.rb
    Constants::STATES.each do |state|
      make_municipalities_for_state(state)
    end

    #
    # Correct municipality slug names
    #

    # Vermont:
    # http://www.vt251.com/vt/town_links.php
    # http://www.census.gov/geo/www/maps/DC10_GUBlkMap/cousub/dc10blk_st50_cousub.html
    municipality = Municipality.find_by_slug('alburg-vt')
    municipality.name = 'Alburgh'
    municipality.slug = 'alburgh-vt'
    municipality.save!

    municipality = Municipality.find_by_code_fips('5001161675')
    municipality.name = 'St. Albans City'
    municipality.slug = 'st-albans-city-vt'
    municipality.save!

    municipality = Municipality.find_by_code_fips('5001161750')
    municipality.name = 'St. Albans Town'
    municipality.slug = 'st-albans-town-vt'
    municipality.save!

    municipality = Municipality.find_by_code_fips('5001948850')
    municipality.name = 'Newport City'
    municipality.slug = 'newport-city-vt'
    municipality.save!

    municipality = Municipality.find_by_code_fips('5001948925')
    municipality.name = 'Newport Town'
    municipality.slug = 'newport-town-vt'
    municipality.save!
  end

  # Populate Municipality date for the given state pair.
  #
  # @param state_pair [Array] State key and state abbreviation pair
  def make_municipalities_for_state(state_pair)
    state = state_pair[0]
    url   = "http://api.usatoday.com/open/census/loc?keypat=#{state}&sumlevid=4,6&api_key=#{Constants::USA_TODAY_API_KEY}"

    puts "Retrieving municipalities for #{state_pair[1]}..."

    municipalities = []
    for i in 1..10
      begin
        data = RestClient.get(url)
        json = JSON.parse(data)

        json['response'].each do |p|
          name = p['Placename']

          housing_units     = p['HousingUnits']
          housing_vacancies = (p['PctVacant'].to_f * housing_units.to_i).ceil

          # populate the new Municipality
          municipality = Municipality.new
          municipality.name                     = name
          municipality.state                    = state
          municipality.slug                     = Municipality.create_slug(name, state)
          municipality.code_fips                = p['FIPS']
          municipality.code_gnis                = p['GNIS']
          municipality.population               = p['Pop']
          municipality.population_density       = p['PopSqMi']
          municipality.race_american_indian     = p['PctAmInd']
          municipality.race_asian               = p['PctAsian']
          municipality.race_black               = p['PctBlack']
          municipality.race_hispanic            = p['PctHisp']
          municipality.race_multiple            = p['PctTwoOrMore']
          municipality.race_non_hispanic        = p['PctNonHisp']
          municipality.race_non_hispanic_white  = p['PctNonHispWhite']
          municipality.race_other               = p['PctOther']
          municipality.race_pacific_islander    = p['PctNatHawOth']
          municipality.race_white               = p['PctWhite']
          municipality.diversity                = p['USATDiversityIndex']
          municipality.area_land                = p['LandSqMi']
          municipality.area_water               = p['WaterSqMi']
          municipality.latitude                 = p['Lat']
          municipality.longitude                = p['Long']
          municipality.housing_units            = housing_units
          municipality.housing_vacancies        = housing_vacancies

          municipalities << municipality
        end
        break # for i in 1..10
      rescue => e
        puts "Caught exception: #{e.message} (Attempt #{i})"
        municipalities = []
        sleep(5)
      end
    end

    Municipality.import(municipalities)
  end

  # Update known Municipalities with website information.
  def update_municipalities
    puts 'Updating municipality information...'

    #
    # Connecticut
    #

    municipality = Municipality.find_by_slug('glastonbury-ct')
    municipality.website = 'http://www.glasct.org'
    municipality.website_skip_links = '^/index.aspx\?page=18& ^/index.aspx\?page=836$ ^/LanapCaptcha.aspx'
    municipality.save!

    #
    # Massachusetts
    #

    # Temporarily disabled Cambridge due to infinite crawl of a calendar
    municipality = Municipality.find_by_slug('cambridge-ma')
    municipality.website = nil
    #municipality.website = 'http://www.cambridgema.gov'
    municipality.website_skip_links = '^/citycalendar.aspx ^/cpl/calendarofevents.aspx Calendar.aspx ^/peace/copyofcalendar.aspx'
    municipality.save!

    # Temporarily disabled Somerville due to tons of duplicate links
    municipality = Municipality.find_by_slug('somerville-ma')
    municipality.website = nil
    #municipality.website = 'http://www.somervillema.gov'
    municipality.website_skip_links = '^/calendar[/\?]'
    municipality.save!

    municipality = Municipality.find_by_slug('watertown-town-ma')
    municipality.display_name = 'Watertown'
    municipality.website = 'http://www.ci.watertown.ma.us'
    municipality.website_skip_links = '^/Calendar.aspx'
    municipality.save!

    #
    # Maryland
    #

    municipality = Municipality.find_by_slug('baltimore-md')
    municipality.website = 'http://www.baltimorecity.gov'
    municipality.save!

    #
    # Vermont
    #

    municipality = Municipality.find_by_slug('alburgh-vt')
    municipality.website = 'http://www.alburghvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('arlington-vt')
    municipality.website = 'http://www.arlingtonvt.org'
    municipality.website_skip_links = '^/calendar ^/\?page_id=246&'
    municipality.save!

    municipality = Municipality.find_by_slug('barnet-vt')
    municipality.website = 'http://www.barnetvt.org'
    municipality.website_linkable_domains = 'http://www.kevaco.com'
    municipality.save!

    municipality = Municipality.find_by_slug('barre-vt')
    municipality.website = 'http://www.barrecity.org'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7BC8159E3A-E1C0-4F08-B715-DA6AA355AB91%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('barton-vt')
    municipality.website = 'http://www.townofbarton.com'
    municipality.save!

    municipality = Municipality.find_by_slug('bennington-vt')
    municipality.website = 'http://www.bennington.com/town'
    municipality.save!

    municipality = Municipality.find_by_slug('benson-vt')
    municipality.website = 'http://www.benson-vt.com'
    municipality.website_skip_links = '^/cgi-bin/calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('berlin-vt')
    municipality.website = 'http://www.berlinvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('bethel-vt')
    municipality.website = 'http://bethelvt.govoffice3.com'
    municipality.save!

    municipality = Municipality.find_by_slug('bolton-vt')
    municipality.website = 'http://www.boltonvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('bradford-vt')
    municipality.website = 'http://www.bradford-vt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('braintree-vt')
    municipality.website = 'http://www.braintreevt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('brandon-vt')
    municipality.website = 'http://townofbrandon.com'
    municipality.save!

    municipality = Municipality.find_by_slug('brattleboro-vt')
    municipality.website = 'http://www.brattleboro.org'
    municipality.save!

    municipality = Municipality.find_by_slug('brighton-vt')
    municipality.website = 'http://brightonvt.org'
    municipality.website_skip_links = '^/calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('bristol-vt')
    municipality.website = 'http://www.bristolvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('brookfield-vt')
    municipality.website = 'http://www.brookfieldvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('brookline-vt')
    municipality.website = 'http://brooklinevt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('burke-vt')
    municipality.website = 'http://www.burkevermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('burlington-vt')
    municipality.website = 'http://www.burlingtonvt.gov'
    municipality.website_skip_links = '^/Calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('cabot-vt')
    municipality.website = 'http://www.cabotvt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('calais-vt')
    municipality.website = 'http://www.calaisvermont.gov'
    municipality.website_skip_links = 'Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('cambridge-vt')
    municipality.website = 'http://www.townofcambridgevt.org'
    municipality.website_skip_links = '^/calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('canaan-vt')
    municipality.website = 'http://www.canaanvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('castleton-vt')
    municipality.website = 'http://www.bsi-vt.com/castleton http://castletonvermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('cavendish-vt')
    municipality.website = 'http://cavendishvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('charleston-vt')
    municipality.website = 'http://www.charlestonvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('charlotte-vt')
    municipality.website = 'http://www.charlottevt.org'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7BE862D1DD-33A3-42A3-AE9D-8C521504C747%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('chelsea-vt')
    municipality.website = 'http://www.chelseavt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('chester-vt')
    municipality.website = 'http://chester.govoffice.com'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B088978BF-EE58-4B1D-B384-982372B41773%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('clarendon-vt')
    municipality.website = 'http://www.clarendonvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('colchester-vt')
    municipality.website = 'http://colchestervt.gov'
    municipality.save!

    municipality = Municipality.find_by_slug('concord-vt')
    municipality.website = 'http://www.concordvt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('corinth-vt')
    municipality.website = 'http://www.corinthvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('cornwall-vt')
    municipality.website = 'http://cornwallvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('craftsbury-vt')
    municipality.website = 'http://www.townofcraftsbury.com'
    municipality.save!

    municipality = Municipality.find_by_slug('danville-vt')
    municipality.website = 'http://www.danvillevt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('derby-vt')
    municipality.website = 'http://www.derbyvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('dorset-vt')
    municipality.website = 'http://dorsetvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('dover-vt')
    municipality.website = 'http://doververmont.com'
    municipality.save!

    municipality = Municipality.find_by_slug('dummerston-vt')
    municipality.website = 'http://dummerston.org'
    municipality.save!

    municipality = Municipality.find_by_slug('duxbury-vt')
    municipality.website = 'http://duxburyvermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('eden-vt')
    municipality.website = 'http://www.edenvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('elmore-vt')
    municipality.website = 'http://www.elmorevt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('enosburg-vt')
    municipality.website = 'http://enosburghvermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('essex-vt')
    municipality.website = 'http://www.essex.org'
    municipality.website_skip_links = '^/add-event/ ^/calendar/ /doc_details/ /doc_view/ ^/news/calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('fair-haven-vt')
    municipality.website = 'http://www.fairhavenvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('fairfax-vt')
    municipality.website = 'http://www.fairfaxvt.com'
    municipality.website_skip_links = '^/calendar'
    municipality.save!

    municipality = Municipality.find_by_slug('fairfield-vt')
    municipality.website = 'http://www.fairfieldvermont.us/wordpress'
    municipality.website_skip_links = '\?month=\w*&yr=\d*$ ^/wordpress/calendar/$'
    municipality.save!

    municipality = Municipality.find_by_slug('fairlee-vt')
    municipality.website = 'http://www.fairleevt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('fayston-vt')
    municipality.website = 'http://www.faystonvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('ferrisburgh-vt')
    municipality.website = 'http://ferrisburghvt.org'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B7A8F72CF-ED85-4BCD-9F86-D8CA9C99D15E%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('fletcher-vt')
    municipality.website = 'http://fletchervt.net'
    municipality.save!

    municipality = Municipality.find_by_slug('franklin-vt')
    municipality.website = 'http://www.franklinvermont.com'
    municipality.save!

    municipality = Municipality.find_by_slug('georgia-vt')
    municipality.website = 'http://townofgeorgia.com'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B67D77739-8593-4EC9-AB98-FB79A3B45AF3%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('glover-vt')
    municipality.website = 'http://www.townofglover.com'
    municipality.save!

    municipality = Municipality.find_by_slug('goshen-vt')
    municipality.website = 'http://goshenvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('grafton-vt')
    municipality.website = 'http://www.graftonvermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('grand-isle-vt')
    municipality.website = 'http://grandislevt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('granville-vt')
    municipality.website = 'http://www.granvillevermont.org'
    municipality.website_skip_links = '^/index.php\?option=com_jcalpro'
    municipality.website_strip_params = '^date$ ^limit$'
    municipality.save!

    municipality = Municipality.find_by_slug('guildhall-vt')
    municipality.website = 'http://www.guildhallvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('greensboro-vt')
    municipality.website = 'http://greensborovt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('groton-vt')
    municipality.website = 'http://www.grotonvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('guildhall-vt')
    municipality.website = 'http://www.guildhallvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('guilford-vt')
    municipality.website = 'http://www.guilfordvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('halifax-vt')
    municipality.website = 'http://www.halifaxvermont.com'
    municipality.save!

    municipality = Municipality.find_by_slug('hardwick-vt')
    municipality.website = 'http://www.hardwickvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('hartford-vt')
    municipality.website = 'http://www.hartford-vt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('hartland-vt')
    municipality.website = 'http://www.hartland.govoffice.com'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7BF4B6B828-2DC9-4153-9BAF-212AAF3965D5%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('highgate-vt')
    municipality.website = 'http://highgate.weebly.com'
    municipality.save!

    municipality = Municipality.find_by_slug('hinesburg-vt')
    municipality.website = 'http://www.hinesburg.org'
    municipality.save!

    municipality = Municipality.find_by_slug('huntington-vt')
    municipality.website = 'http://huntingtonvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('hyde-park-vt')
    municipality.website = 'http://hydeparkvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('irasburg-vt')
    municipality.website = 'http://irasburgvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('isle-la-motte-vt')
    municipality.website = 'http://www.islelamotte.us'
    municipality.save!

    municipality = Municipality.find_by_slug('jamaica-vt')
    municipality.website = 'http://www.jamaicavermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('jay-vt')
    municipality.website = 'http://www.jayvt.com'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7BAC2B8545-D9A7-4440-892B-573D6B37D4BE%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('jericho-vt')
    municipality.website = 'http://jerichovt.gov'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7BB4A5F462-1CAA-43EC-921A-6AD91CA6680B%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('johnson-vt')
    # TODO
    # I had to explicitly add a URL for the minutes page, as it's currently linked via JavaScript
    municipality.website = 'http://townofjohnson.com http://townofjohnson.com/Government/Town/MeetingMinutes/tabid/931/Default.aspx'
    municipality.save!

    municipality = Municipality.find_by_slug('killington-vt')
    municipality.website = 'http://www.killingtontown.com'
    municipality.save!

    municipality = Municipality.find_by_slug('leicester-vt')
    municipality.website = 'http://www.leicestervt.org'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7BF038F8FB-B941-443D-BF06-AA649CC08735%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('lincoln-vt')
    municipality.website = 'http://www.lincolnvermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('londonderry-vt')
    municipality.website = 'http://www.londonderryvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('ludlow-vt')
    municipality.website = 'http://www.ludlow.vt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('lyndon-vt')
    municipality.website = 'http://lyndonvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('maidstone-vt')
    municipality.website = 'http://www.maidstone-vt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('manchester-vt')
    municipality.website = 'http://www.manchester-vt.gov'
    municipality.save!

    municipality = Municipality.find_by_slug('marlboro-vt')
    municipality.website = 'http://marlboro.vt.us'
    municipality.website_skip_links = '^/event'
    municipality.save!

    municipality = Municipality.find_by_slug('marshfield-vt')
    municipality.website = 'http://www.town.marshfield.vt.us'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7BD0A32F8D-D5DC-42C7-B77E-DB9497F8D558%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('mendon-vt')
    municipality.website = 'http://www.mendonvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('middlebury-vt')
    municipality.website = 'http://www.middlebury.govoffice.com'
    municipality.save!

    municipality = Municipality.find_by_slug('middlesex-vt')
    municipality.website = 'http://middlesexvermont.org'
    municipality.website_skip_links = '^/calendar/$'
    municipality.save!

    municipality = Municipality.find_by_slug('milton-vt')
    municipality.website = 'http://miltonvt.org'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B2C3A4B68-CDBC-4EC5-AD52-949F6139602D%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('monkton-vt')
    municipality.website = 'http://monktonvt.com'
    municipality.website_skip_links = '^/scheduler/'
    municipality.save!

    municipality = Municipality.find_by_slug('montgomery-vt')
    municipality.website = 'http://www.montgomeryvt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('montpelier-vt')
    municipality.website = 'http://www.montpelier-vt.org'
    municipality.website_accept_cookies = true
    municipality.website_skip_links = '^/phpicalendar/'
    municipality.website_strip_params = '^id$ ^mv_'
    municipality.save!

    municipality = Municipality.find_by_slug('moretown-vt')
    municipality.website = 'http://www.moretownvt.org'
    municipality.website_skip_links = 'calendar'
    municipality.save!

    municipality = Municipality.find_by_slug('morgan-vt')
    municipality.website = 'http://town.morgan-vt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('morristown-vt')
    municipality.website = 'http://morristownvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('mount-holly-vt')
    municipality.website = 'http://www.mounthollyvt.org'
    municipality.website_skip_links = '^/calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('new-haven-vt')
    municipality.website = 'http://newhavenvt.com'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B4E4D0A26-5579-4C34-8304-0BA515239DA6%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('newfane-vt')
    municipality.website = 'http://www.newfanevt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('newport-city-vt')
    municipality.website = 'http://www.newportvermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('north-hero-vt')
    municipality.website = 'http://www.northherovt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('northfield-vt')
    municipality.website = 'http://www.northfield-vt.gov'
    municipality.save!

    municipality = Municipality.find_by_slug('norwich-vt')
    municipality.website = 'http://norwich.vt.us'
    municipality.website_skip_links = '^/calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('orange-vt')
    municipality.website = 'http://www.orangevt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('orwell-vt')
    municipality.website = 'http://www.town-of-orwell.org'
    municipality.website_skip_links = '^/htm/calendar\.html'
    municipality.save!

    municipality = Municipality.find_by_slug('panton-vt')
    municipality.website = 'http://www.pantonvt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('pawlet-vt')
    municipality.website = 'http://pawlet.vt.gov'
    municipality.save!

    municipality = Municipality.find_by_slug('peacham-vt')
    municipality.website = 'http://www.peacham.net'
    municipality.save!

    municipality = Municipality.find_by_slug('pittsfield-vt')
    municipality.website = 'http://www.pittsfieldvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('pittsford-vt')
    municipality.website = 'http://pittsfordvermont.com'
    municipality.website_skip_links = '^/events/'
    municipality.save!

    municipality = Municipality.find_by_slug('plainfield-vt')
    municipality.website = 'http://www.plainfieldvt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('plymouth-vt')
    municipality.website = 'http://www.plymouthvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('pomfret-vt')
    municipality.website = 'http://pomfretvt.us'
    municipality.save!

    municipality = Municipality.find_by_slug('poultney-vt')
    municipality.website = 'http://www.poultneyvt.com'
    municipality.website_strip_params = '^m$ ^cat$'
    municipality.save!

    municipality = Municipality.find_by_slug('pownal-vt')
    municipality.website = 'http://www.pownalvt.org'
    municipality.website_strip_params = '^month$ ^yr$'
    municipality.save!

    municipality = Municipality.find_by_slug('proctor-vt')
    municipality.website = 'http://proctorvermont.com'
    municipality.save!

    municipality = Municipality.find_by_slug('putney-vt')
    municipality.website = 'http://www.putneyvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('randolph-vt')
    municipality.website = 'http://randolphvt.govoffice2.com'
    municipality.save!

    municipality = Municipality.find_by_slug('reading-vt')
    municipality.website = 'http://www.readingvt.govoffice.com'
    municipality.website_skip_links = '/index.asp\?Type=NONE&SEC=%7B804468E8-CEE3-407D-8F3E-33AF9B67D8CA%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('readsboro-vt')
    municipality.website = 'http://www.officialtownofreadsboro.org'
    municipality.website_skip_links = '^/displaycalendar\.php'
    municipality.save!

    municipality = Municipality.find_by_slug('richford-vt')
    municipality.website = 'http://www.richfordvt.com/'
    municipality.website_skip_links = '^/event'
    municipality.save!

    municipality = Municipality.find_by_slug('richmond-vt')
    municipality.website = 'http://www.richmondvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('ripton-vt')
    municipality.website = 'http://www.riptonvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('rochester-vt')
    municipality.website = 'http://www.rochestervermont.org'
    municipality.website_skip_links = '^/calendar ^/\d\d\d\d'
    municipality.save!

    municipality = Municipality.find_by_slug('rockingham-vt')
    municipality.website = 'http://www.rockbf.org'
    municipality.save!

    municipality = Municipality.find_by_slug('roxbury-vt')
    municipality.website = 'http://www.roxbury.govoffice2.com'
    municipality.save!

    municipality = Municipality.find_by_slug('royalton-vt')
    municipality.website = 'http://royaltonvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('rutland-vt')
    municipality.website = 'http://rutland.govoffice.com'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B946CE40E-3E60-47A1-9D78-D96F4B064803%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('salisbury-vt')
    municipality.website = 'http://townofsalisbury.org'
    municipality.save!

    municipality = Municipality.find_by_slug('sandgate-vt')
    municipality.website = 'http://sandgatevermont.com'
    municipality.save!

    municipality = Municipality.find_by_slug('shaftsbury-vt')
    municipality.website = 'http://www.shaftsbury.net'
    municipality.save!

    municipality = Municipality.find_by_slug('sharon-vt')
    municipality.website = 'http://www.sharonvt.net'
    municipality.website_skip_links = '^/community-calendar'
    municipality.save!

    municipality = Municipality.find_by_slug('shelburne-vt')
    municipality.website = 'http://www.shelburnevt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('shoreham-vt')
    municipality.website = 'http://www.shorehamvt.org/town'
    municipality.website_skip_links = '^/town/community/calevents\.shtml'
    municipality.save!

    municipality = Municipality.find_by_slug('shrewsbury-vt')
    municipality.website = 'http://www.shrewsburyvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('south-burlington-vt')
    municipality.website = 'http://www.sburl.com'
    municipality.save!

    municipality = Municipality.find_by_slug('south-hero-vt')
    municipality.website = 'http://www.southherovt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('springfield-vt')
    municipality.website = 'http://springfieldvt.govoffice2.com'
    municipality.save!

    municipality = Municipality.find_by_slug('st-albans-city-vt')
    municipality.website = 'http://www.stalbansvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('st-albans-town-vt')
    municipality.website = 'http://www.stalbanstown.com'
    municipality.save!

    municipality = Municipality.find_by_slug('st-george-vt')
    municipality.website = 'http://www.stgeorgevt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('st-johnsbury-vt')
    municipality.website = 'http://www.town.st-johnsbury.vt.us'
    municipality.website_skip_links = 'Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('stamford-vt')
    municipality.website = 'http://www.stamfordvt.org'
    municipality.website_skip_links = '^/towncalendar\.html'
    municipality.save!

    municipality = Municipality.find_by_slug('starksboro-vt')
    municipality.website = 'https://sites.google.com/a/starksboro.org/starksboro'
    municipality.website_skip_links = '^/a/starksboro.org/starksboro/calendar$'
    municipality.save!

    municipality = Municipality.find_by_slug('stowe-vt')
    municipality.website = 'http://www.townofstowevt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('strafford-vt')
    municipality.website = 'http://www.townofstraffordvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('stratton-vt')
    municipality.website = 'http://townofstrattonvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('sunderland-vt')
    municipality.website = 'http://www.sunderlandvt.org'
    municipality.website_skip_links = '^/calendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('swanton-vt')
    municipality.website = 'http://www.swantonvermont.org'
    municipality.save!

    municipality = Municipality.find_by_slug('thetford-vt')
    municipality.website = 'http://www.thetfordvermont.us'
    municipality.save!

    municipality = Municipality.find_by_slug('tinmouth-vt')
    municipality.website = 'http://tinmouthvt.org'
    municipality.website_skip_links = '^/MainPages/Events/Calendar\.php'
    municipality.save!

    municipality = Municipality.find_by_slug('topsham-vt')
    municipality.website = 'http://www.topshamvt.org'
    municipality.website_skip_links = '^/search[/\?]'
    municipality.save!

    municipality = Municipality.find_by_slug('townshend-vt')
    municipality.website = 'http://www.townshendvt.net'
    municipality.save!

    municipality = Municipality.find_by_slug('troy-vt')
    municipality.website = 'http://www.troyvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('tunbridge-vt')
    municipality.website = 'http://www.tunbridgevt.com'
    municipality.website_skip_links = '^/news/events'
    municipality.save!

    municipality = Municipality.find_by_slug('underhill-vt')
    municipality.website = 'http://www.underhillvt.gov'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B0349A2C8-E5FE-4A9A-A432-1B903125E3A7%7D'
    municipality.save!

    municipality = Municipality.find_by_slug('vergennes-vt')
    municipality.website = 'http://vergennes.org'
    municipality.save!

    municipality = Municipality.find_by_slug('vernon-vt')
    municipality.website = 'http://www.vernon-vt.org/home.html'
    municipality.save!

    municipality = Municipality.find_by_slug('vershire-vt')
    municipality.website = 'http://www.vershirevt.org http://www.vershirevt.org/20100504212025.html http://www.vershirevt.org/20100219202457.html http://www.vershirevt.org/2.html http://www.vershirevt.org/sbm0000.html http://www.vershirevt.org/pcm0000.html'
    municipality.save!

    municipality = Municipality.find_by_slug('waitsfield-vt')
    municipality.website = 'http://www.waitsfieldvt.us'
    municipality.website_skip_links = '^/calendar/index\.cfm'
    municipality.save!

    municipality = Municipality.find_by_slug('wallingford-vt')
    municipality.website = 'http://www.wallingfordvt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('warren-vt')
    municipality.website = 'http://www.warrenvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('waterbury-vt')
    municipality.website = 'http://www.waterburyvt.com'
    municipality.website_skip_links = 'calendar'
    municipality.save!

    municipality = Municipality.find_by_slug('weathersfield-vt')
    municipality.website = 'http://www.weathersfieldvt.org'
    municipality.website_skip_links = '^/calendar-of-events/ ^/component/mailto/ /orderby,[1,3-7]'
    municipality.save!

    municipality = Municipality.find_by_slug('weybridge-vt')
    municipality.website = 'http://weybridge.govoffice.com'
    municipality.save!

    municipality = Municipality.find_by_slug('wells-vt')
    municipality.website = 'http://wellsvermont.com'
    municipality.save!

    municipality = Municipality.find_by_slug('west-fairlee-vt')
    municipality.website = 'http://www.westfairleevt.com'
    municipality.save!

    municipality = Municipality.find_by_slug('west-rutland-vt')
    municipality.website = 'http://westrutlandtown.com'
    municipality.save!

    municipality = Municipality.find_by_slug('west-windsor-vt')
    municipality.website = 'http://www.westwindsorvt.govoffice2.com'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B1975B07A-557D-4B2F-8F8B-B95BE0ABD1B2%7D ^/index.asp\?Type=NONE&SEC=%7B2EE3523D-ADA8-4596-A43B-439A1D97E48B%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('westfield-vt')
    municipality.website = 'http://www.cityofwestfield.org'
    municipality.website_skip_links = '/\?page_id=87'
    municipality.save!

    municipality = Municipality.find_by_slug('westford-vt')
    municipality.website = 'http://www.westfordvt.us'
    municipality.website_skip_links = '^/eventCal\.php ^/phpEventCalendar/'
    municipality.save!

    municipality = Municipality.find_by_slug('westminster-vt')
    municipality.website = 'http://www.westminstervt.org'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B729DA077-8029-4704-9921-B86D371B7139%7D ^/index.asp\?Type=NONE&SEC=%7B77D0D03D-845C-4BE0-9BBE-FEFB06F888FB%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('westmore-vt')
    municipality.website = 'http://www.westmoreonline.org'
    municipality.website_skip_links = '/main/\?page_id=25'
    municipality.save!

    municipality = Municipality.find_by_slug('weston-vt')
    municipality.website = 'http://www.westonvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('williamstown-vt')
    municipality.website = 'http://www.williamstownvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('williston-vt')
    municipality.website = 'http://town.williston.vt.us'
    municipality.website_skip_links = '^/index.asp\?Type=B_EV&SEC=%7B3F0933E9-BBC9-47F8-9CE3-1BC0C5AE2516%7D ^/index.asp\?Type=NONE&SEC=%7B7D6B25DD-E890-4E5C-8EFD-C4A58AEC7872%7D Design=PrintView$'
    municipality.save!

    municipality = Municipality.find_by_slug('wilmington-vt')
    municipality.website = 'http://www.wilmingtonvermont.us'
    municipality.save!

    municipality = Municipality.find_by_slug('windsor-vt')
    municipality.website = 'http://www.windsorvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('winooski-vt')
    municipality.website = 'http://winooskivt.org/htm/top4.htm'
    municipality.save!

    municipality = Municipality.find_by_slug('wolcott-vt')
    municipality.website = 'http://www.wolcottvt.org'
    municipality.save!

    municipality = Municipality.find_by_slug('woodbury-vt')
    municipality.website = 'http://www.woodburyvt.org'
    municipality.website_skip_links = '^/events\.html'
    municipality.save!

    municipality = Municipality.find_by_slug('woodstock-vt')
    municipality.website = 'http://www.woodstockvt.com'
    municipality.website_skip_links = '^/events\.php'
    municipality.website_strip_params = '^month$ ^year$ ^view$'
    municipality.save!

    municipality = Municipality.find_by_slug('worcester-vt')
    municipality.website = 'http://www.worcestervt.org'
    municipality.website_skip_links = '^/calendar ^/\d\d\d\d'
    municipality.save!
  end
end