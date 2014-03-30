# encoding: utf-8

include ApplicationHelper

class Document < ActiveRecord::Base
  include Tire::Model::Search

  validates :guid,        :uniqueness => true
  validates :content_url, :uniqueness => true

  belongs_to :municipality
  has_many :entities, :dependent => :delete_all

  attr_accessor :short_text

  attr_accessible :extracted_text,
                  :title,
                  :classification,
                  :legislative_body,
                  :status,
                  :useful,
                  :summary,
                  :likely_date,
                  :people,
                  :locations,
                  :organizations,
                  :terms

  serialize :people
  serialize :organizations
  serialize :locations
  serialize :terms

  default_scope where(:state => 'PROCESSED')

  acts_as_paranoid
  has_paper_trail

  @@http_client = HTTPClient.new
  @@http_client.connect_timeout = Constants::DEFAULT_HTTP_TIMEOUT

  # ElasticSearch Mappings
  mapping do
    indexes :api_version, :type => 'string', :index => 'not_analyzed'
    indexes :id, :type => 'string', :index => 'not_analyzed'
    indexes :guid, :type => 'string', :index => 'not_analyzed'
    indexes :title, :type => 'string', :boost => 2.0, :analyzer => 'snowball'
    indexes :summary, :type => 'string', :analyzer => 'snowball',  :tokenizer => 'standard'
    indexes :extracted_text, :type => 'string', :analyzer => 'snowball',  :tokenizer => 'standard'
    indexes :municipality_name, :type => 'string', :index => 'not_analyzed'
    indexes :municipality_state, :type => 'string', :index => 'not_analyzed'
    indexes :municipality_slug, :type => 'string', :index => 'not_analyzed'
    indexes :content_type, :type => 'string', :index => 'not_analyzed'
    indexes :last_modified, :type => 'date', :index => 'not_analyzed'
    indexes :created_at, :type => 'date', :index => 'not_analyzed'
    indexes :updated_at, :type => 'date', :index => 'not_analyzed'
    indexes :likely_date, :type => 'date', :index => 'not_analyzed'
    indexes :legislative_body, :type => 'string', :index => 'not_analyzed'
    indexes :classification, :type => 'string', :index => 'not_analyzed'
    indexes :people, :boost => 2.0, :analyzer => 'snowball'
    indexes :organizations, :boost => 2.0, :analyzer => 'snowball'
    indexes :locations, :boost => 2.0, :analyzer => 'snowball'
    indexes :content_url, :type => 'string', :index => 'not_analyzed'
  end

  def to_indexed_json
    # TODO:
    # Probably don't want to use this here but not sure how to get around that yet.
    document = self.extend(V1::DocumentRepresenter)
    return document.to_json
  end

  scope :past_day, lambda { where("updated_at > ?", 1.days.ago ) }
  scope :past_week, lambda { where("updated_at > ?", 7.days.ago ) }
  scope :past_month, lambda { where("updated_at > ?", 1.month.ago ) }
  scope :past_half_year, lambda { where("updated_at > ?", 6.month.ago ) }
  scope :older_than_one_month, lambda { where("updated_at < ?", 1.month.ago ) }

  def phone_numbers
    if !extracted_text.nil?
      regex = /\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$*/
      matches = extracted_text.scan(regex)
      numbers = []
      matches.each do |match|
        numbers << match.join("-")
      end
      return numbers
    end
  end

  #
  # Shortcuts to classification web service.
  #
  def guess_meeting
    url = "#{Constants::TEXT_CLASSIFIER_URL}/classify?"
    body = {'classifier_name' => 'meeting', 'text' => text_for_classification }
    begin
      response = @@http_client.post(url, body)
      response.body[0..254]
    rescue
      nil
    end
  end

  def train_meeting(classification)
    url = "#{Constants::TEXT_CLASSIFIER_URL}/train?"
    body = {'classifier_name' => 'meeting', 'classification' => classification, 'text' => text_for_classification }
    begin
      response = @@http_client.post(url, body)
      response.body[0..254]
    rescue
    end
  end

  def guess_legislative_body
    url = "#{Constants::TEXT_CLASSIFIER_URL}/classify?"
    body = {'classifier_name' => 'legislative_body', 'text' => text_for_classification }
    begin
      response = @@http_client.post(url, body)
      response.body[0..254]
    rescue
    end
  end

  def train_legislative_body(classification)
    url = "#{Constants::TEXT_CLASSIFIER_URL}/train?"
    body = {'classifier_name' => 'legislative_body', 'classification' => classification, 'text' => text_for_classification }
    begin
      response = @@http_client.post(url, body)
      response.body[0..254]
    rescue
    end
  end

  attr_accessor :text_for_classification
  def text_for_classification
    return @text_for_classification unless @text_for_classification.nil?
    text = ""
    text += short_text unless short_text.nil?
    text += summary unless summary.nil?
    text += guessed_topics unless guessed_topics.nil?
    text += URI(content_url).path
    unless guessed_terms.nil?
      guessed_terms.each do |key|
        text += " #{key[0]} "
      end
    end

    text = text.to_s.downcase

    text = text.to_s.gsub(/#{Regexp.escape(municipality.name)}/i, " ")
    text = text.to_s.gsub(":", "")
    text = text.to_s.gsub("\\", " ")
    text = text.to_s.gsub(",", " ")
    text = text.to_s.gsub(".", " ")
    text = text.to_s.gsub("/", " ")
    text = text.to_s.gsub("-", " ")
    text = text.to_s.gsub("(", " ")
    text = text.to_s.gsub(")", " ")
    text = text.to_s.gsub(".", " ")
    text = text.to_s.gsub("%", " ")
    text = text.to_s.gsub("+", " ")
    text = text.to_s.gsub("\"", " ")
    #remove numbers
    text = text.to_s.gsub(/\d{1,6}/, " ")
    # remove single characters
    text = text.to_s.gsub(/\s\S\s/, " ")
    text = text.to_s.gsub(/ [a-zA-Z]{0,3} /, " ")
    text = text.to_s.gsub(/ [a-zA-Z]{0,2} /, " ")

    # Filter out People, Locations
    unless named_people.nil?
      if named_people.kind_of?(Array)
        words = named_people.join(" ").split(" ")
      else
        words = [named_people]
      end
      words = named_people.join(" ").split(" ")
      words.each do |word|
        # remove the word
        text.to_s.gsub!(/#{Regexp.escape(word)}/i, " ")
      end
    end

    unless named_locations.nil?
      if named_locations.kind_of?(Array)
        words = named_locations.join(" ").split(" ")
      else
        words = [named_locations]
      end
      words.each do |word|
        # remove the word
        text.to_s.gsub!(/#{Regexp.escape(word)}/i, " ")
      end
    end

    text.gsub!(/(\$|\*|\?|\!|&|#|_|•)/, "")
    text.gsub!(/\s(January|February|March|April|May|June|July|August|September|October|November|December)\s/i, " ")
    text.gsub!(/\s(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sept|Oct|Nov|Dec)\s/i, " ")
    text.gsub!(/\s(Street|Avenue)\s/i, " ")
    text.gsub!(/\s(City|Town|Village)\s/i, " ")
    text.gsub!(/'s/, " ")
    text.gsub!(/\sdocx\s/, " ")
    text.gsub!(/\s(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s/i, " ")

    text = text.gsub(/\s+/, " ").strip
    text = text.split(" ").sort.join(" ")

    @text_for_classification = text
  end

  attr_accessor :summary
  def summary
    return @summary unless @summary.nil?
    unless extracted_text.nil?
      ratio = 50
      case extracted_text.split.size
        when 0..100
          ratio = 100
        when 100..1000
          ratio = 25
        else
          ratio = 10
      end
      url = "#{Constants::TEXT_SUMMARIZER_URL}/summarize?"
      body = {'ratio' => ratio, 'text' => extracted_text }
      begin
        response = @@http_client.post(url, body)
        @summary = response.body
      rescue
      end
    end
  end

  attr_accessor :named_people
  def named_people
    return @named_people unless @named_people.nil?
    unless named_entities.nil?
      @named_people = named_entities["entities"]["person"]
      unless @named_people.nil?
        if @named_people.respond_to?('uniq!')
          @named_people.uniq!
          if @named_people.respond_to?('sort!')
            @named_people.sort!
          end
        end
      end
    end
  end

  attr_accessor :named_locations
  def named_locations
    return @named_locations unless @named_locations.nil?
    unless named_entities.nil?
      @named_locations = named_entities["entities"]["location"]
      unless @named_locations.nil?
        if @named_locations.respond_to?('uniq!')
          @named_locations.uniq!
          if @named_locations.respond_to?('sort!')
            @named_locations.sort!
          end
        end
      end
    end
  end

  attr_accessor :named_organizations
  def named_organizations
    return @named_organizations unless @named_organizations.nil?
    unless named_entities.nil?
      @named_organizations = named_entities["entities"]["organization"]
      unless @named_organizations.nil?
        if @named_organizations.respond_to?('uniq!')
          @named_organizations.uniq!
          if @named_organizations.respond_to?('sort!')
            @named_organizations.sort!
          end
        end
      end
    end
  end

  attr_accessor :named_entities
  def named_entities
    return @named_entities unless @named_entities.nil?
    unless extracted_text.nil?
      url = "#{Constants::TEXT_ENTITIES_URL}/classify?"
      body = { 'data' => extracted_text }
      extheader = { 'Accept' => 'application/json' }
      response = @@http_client.post(url, body, extheader)
      begin
        @named_entities = JSON.parse(response.body)
      rescue Exception => e
        puts e.message
        puts e.backtrace.inspect
      end
    end
    return @named_entities
  end

  attr_accessor :guessed_topics
  def guessed_topics
    return @guessed_topics unless @guessed_topics.nil?
    unless extracted_text.nil?
      url = "#{Constants::TEXT_SUMMARIZER_URL}/topics?}"
      body = { 'text' => extracted_text }
      begin
        response = @@http_client.post(url, body)
        @guessed_topics = response.body.gsub(",", ", ")
      rescue
      end
    end
    @guessed_topics = ActionView::Base.full_sanitizer.sanitize(@guessed_topics)
  end

  attr_accessor :guessed_terms
  def guessed_terms
    return @guessed_terms unless @guessed_terms.nil?
    unless extracted_text.nil?
      url = "#{Constants::TEXT_SUMMARIZER_URL}/terms?"
      body = { 'text' => extracted_text }
      begin
        response = @@http_client.post(url, body)
        @guessed_terms = JSON.parse(response.body)
        @guessed_terms = ActionView::Base.full_sanitizer.sanitize(@guessed_terms)
        @guessed_terms = @guessed_terms.sort_by {|a| a[1]}.reverse
      rescue
        # don't raise
      end
    end
  end

  # Return the computed first 50 words of text for this Document.
  def short_text
    # TODO: reset when extracted_text changes
    return @short_text unless @short_text.nil?
    @short_text = safe_squeeze(full_text.to_s.split.to_a[0..50].join(' '))
  end

  #
  # Common content types.
  #

  TEXT_CONTENT_TYPES = [
                        'application/msword',
                        'application/pdf',
                        'application/rss+xml',
                        'application/rtf',
                        'application/vnd.ms-excel',
                        'application/vnd.ms-powerpoint',
                        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                        'application/x-mspublisher',
                        'application/xml',
                        'message/rfc822',
                        'text/calendar',
                        'text/html',
                        'text/htmlcharset=ISO-8859-1',
                        'text/htmlcharset=utf-8',
                        'text/plain',
                        'text/rtf',
                        'text/xml'
                      ]

  IMAGE_CONTENT_TYPES = [
                        'image/bmp',
                        'image/gif',
                        'image/jpeg',
                        'image/png',
                        'image/tiff'
                      ]

  AUDIO_CONTENT_TYPES = [
                        'audio/mp3',
                        'audio/mpeg',
                        'audio/wav',
                        'audio/x-wav'
                      ]

  VIDEO_CONTENT_TYPES = [
                        'video/mpeg',
                        'video/x-ms-wmv'
                      ]

  BINARY_CONTENT_TYPES = [
                        'application/octet-stream'
                      ]

  OTHER_CONTENT_TYPES = [
                        BINARY_CONTENT_TYPES,
                        'application/x-zip-compressed',
                        'application/zip'
                      ].flatten

  #
  # Well-known file extensions.
  #

  EXCEL_FILE_EXTENSIONS = ['xls', 'xlsx', 'xlsm', 'xlsb']
  PPT_FILE_EXTENSIONS   = ['ppt', 'pptx', 'pps', 'ppsx']
  PDF_FILE_EXTENSIONS   = ['pdf']
  WORD_FILE_EXTENSIONS  = ['doc', 'docx']

  PARSEABLE_FILE_EXTENSIONS = [
                        EXCEL_FILE_EXTENSIONS,
                        PPT_FILE_EXTENSIONS,
                        PDF_FILE_EXTENSIONS,
                        WORD_FILE_EXTENSIONS
                      ].flatten

  #
  # Processing states.
  #

  DISCOVERED = 'DISCOVERED'
  PROCESSED  = 'PROCESSED'

  after_commit do |document|
    if state == PROCESSED
      # ElasticSearch
      update_index
    end
  end


  def display_title
    s = ""
    if !extracted_text.nil?
      s = extracted_text.split(" ")[0..20].join(" ")
    else
      s = "No title known"
    end
    return s

    # if legislative_body.blank? || legislative_body == "unknown"
    #   s += " Unknown organization "
    # else
    #   s += " #{legislative_body.titlecase} "
    # end

    # if classification.blank? || classification == "unclassified"
    #   s += " document "
    # else
    #   s += classification.humanize
    # end

    # if !likely_date.nil?
    #   s += " for #{display_date} "
    # end

    return s
  end

  def display_date
    likely_date.to_formatted_s(:long_ordinal)
  end

  #
  # Document content type helpers.
  #

  def self.is_binary?(content_type)
    !content_type.nil? && BINARY_CONTENT_TYPES.include?(content_type.downcase)
  end

  def self.is_html?(content_type)
    !content_type.nil? && content_type.casecmp('text/html') == 0
  end

  def self.is_image?(content_type)
    !content_type.nil? && content_type.downcase.include?('image') == 0
  end

  def self.is_pdf?(content_type)
    !content_type.nil? && content_type.casecmp('application/pdf') == 0
  end

  def self.is_plaintext?(content_type)
    !content_type.nil? && content_type.casecmp('text/plain') == 0
  end

  def self.is_text?(content_type)
    !content_type.nil? && TEXT_CONTENT_TYPES.include?(content_type.downcase)
  end

  def self.is_word?(content_type)
    !content_type.nil? && content_type.casecmp('application/msword') == 0
  end

  def is_binary?
    Document.is_binary?(content_type)
  end

  def is_html?
    Document.is_html?(content_type)
  end

  def is_image?
    Document.is_image?(content_type)
  end

  def is_pdf?
    Document.is_pdf?(content_type)
  end

  def is_plaintext?
    Document.is_plaintext?(content_type)
  end

  def is_text?
    Document.is_text?(content_type)
  end

  def is_word?
    Document.is_word?(content_type)
  end

  #
  # Text extraction methods.
  #

  # Return the computed full text for this Document.
  def full_text
    path = URI(content_url).path.split('/').last
    path = path.nil? ? "" : path.split('.').first

    full_text = "#{path.to_s} #{title.to_s} #{extracted_text.to_s}"
    full_text.downcase!
  end

  # Return the computed first 50 words of text for this Document.
  def short_text
    # TODO: reset when extracted_text changes
    return @short_text unless @short_text.nil?
    @short_text = safe_squeeze(full_text.to_s.split.to_a[0..50].join(' '))
  end

  # TODO:
  # Experimental classification
  def self.train_classifer(classifier, classification, document)
    classifier.train(classification, document.extracted_text)
    classifier.save_state
  end

  # TODO:
  # Experimental classification
  def cls_classify
    Constants::CLS_DRAFT.classify(extracted_text)
  end

  # Used for Best in Place dropdowns
  def display_classifications
    classifications_for_display = []
    Constants::CLASSIFICATIONS.each do |c|
      c.delete_at(2)
      classifications_for_display << c
    end
    return classifications_for_display
  end

  # Classify this Document as one of the well-known classifications.
  def guess_classification
    classification = 'unclassified'
    possible_classifications = Hash.new
    Constants::CLASSIFICATIONS.each do |type|
      matches = short_text.scan(type[2])
      if !matches.nil?
        possible_classifications[type[0]] = matches.size
      end
    end
    possible_classifications = possible_classifications.sort_by{|_key, value| value}.reverse
    # Pick the classification that has the most hits
    if possible_classifications.first[1] > 0
      classification = possible_classifications.first[0]
    else
      "unclassified"
    end
  end

  # Used for Best in Place dropdowns
  def display_organizations
    orgs_for_display = []
    Constants::ORGANIZATIONS.each do |o|
      o.delete_at(2)
      orgs_for_display << o
    end
    return orgs_for_display
  end

  # Determine the organization responsible for this Document.
  #
  # @return the organization responsible for this Document
  def determine_owning_organization
    owning_org = 'unknown'
    Constants::ORGANIZATIONS.each do |body|
      if !body[2].match(short_text).nil?
        owning_org = body[0]
      end
    end
    owning_org
  end


  # Find likely date for this document based on
  # dates we find in the document text and url.
  # This can be wildly off so usually needs manual review.
  #
  # @return the likely date for this document
  def find_likely_dates
    likley_date = nil
    likely_dates = {}
    text = ""
    first_possible_date = nil
    second_possible_date = nil
    third_possible_date = nil

    street_name_regex = /(\d+\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)(\w)*\s(street|st|road|rd|avenue|ave|lane))/i

    begin
      # Often the URL has the date in it and can be the quickest way to get the date
      # This is a pattern that looks much more like a date.
      possible_date = nil
      url = URI.decode(content_url)
      matched_date = url.match(/(\d+\.\d+\.\d+)|(\d+-\d+-\d+)|(\d+_\d+_\d+)|(\d+\/\d+\/\d+)/)
      if !matched_date.nil?
        possible_date = Document.parse_date(matched_date.to_s.gsub(/(_|\.)/, "-"))

      # The dates might not have any normal pattern but are still dates
      # Often the URL has the date as 6 to 8 numerals smashed together like 081210 or 2008-10-12
      elsif !url.match(/\d{6, 8}|\d{6}/).nil?
        matched_date = url.match(/\d{6,8}|\d{6}/)
        s = matched_date.to_s
        if s.length == 8
          # 20121017 becomes 2012-10-17
          s.insert 4, "-"
          s.insert 7, "-"
          possible_date = Document.parse_date(s)
        elsif s.length == 6
          # 121017 becomes 12-10-17
          possible_date = Document.parse_date(s.scan(/.{2}|.+/).join("-"))
        end
      end

      # But the format we get from the url can be way off
      # so we check to see if it is in the future or way in the past
      unless
        (possible_date.to_datetime > 6.months.from_now.to_datetime) ||
        (possible_date.to_datetime < 50.years.ago.to_datetime)

        # This could be a good candidate so we'll add it to the likely_dates
        first_possible_date = possible_date
        likely_dates[:first_date] = first_possible_date
      end
    rescue
      # Ignore
    end

    # There are lots of dates buried in the document text that we extract
    unless extracted_text.nil?

      # Often the date that we want for a document is at the top of the document, so we
      # look there and try to find a date.
      text = extracted_text.gsub(/\n/, " ").gsub(/ +/, ' ').split(" ")[0..50].join(" ")

      # Sometimes dates bump right up with other text 6/29/2011Date Prepared
      # which can throw off the parsers
      match = nil
      match = text.match(/(\/|-|_|\.)\d{4}/)
      unless match.nil?
        text = text.gsub(/(\/|-|_|\.)\d{4}/, match[0]+" ")
      end

      # Sometimes the month name bumps another word which throws off the parsing
      text = text.gsub(/(jan|feb|mar|apr|may|jun|jul|aug|sept|oct|nov|dec)/i, ' \1')

      # The date parsers often pickup street names that start with the first three characters of months
      # So we should strip those out
      text = text.gsub(street_name_regex, '')

      # The Date.parse and Chronic.parse don't work well with periods in dates... remove them
      text = text.gsub(/\./, " ")
      text = safe_squeeze(text)

      # We want the original document date not the date the document was approved.
      # Meeting minutes often have the approved date before the original
      # meeting date. We look for common words that indicate this date might
      # be the approved date.
      approved_position = text.index("approved") || text.index("adopted")
      unless approved_position.nil?
        # skip over a range of text because we don't want this date
        # this is just a guess of how much we need to move it one
        # way or the other
        text = text[approved_position+30..text.length]
      end

      # Check for a second possible date
      begin
        possible_date = nil

        # Look for a commonish date format and try to parse it first
        match = text.match(/\d{1,4}-\d{1,2}-\d{1,4}/)
        unless match.nil?
          begin
            possible_date = Document.parse_date(match.to_s)
          rescue
            # Ignore
          end
        end

        # If we didn't find a possible_date try parsing the entire string
        if possible_date.nil?
          possible_date = Document.parse_date(text)
        end

        # But the format can be way off so we check to see if it is in the
        # future or way in the past
        unless
          (possible_date.to_datetime > 6.months.from_now.to_datetime) ||
          (possible_date.to_datetime < 50.years.ago.to_datetime)

          # This could also be a candidate so we'll add it to the likely_dates
          second_possible_date = possible_date
          likely_dates[:second_date] = second_possible_date
        end
      rescue
        # Ignore
      end

      # Check for a third possible date
      begin
        # Check more of the extracted text to see if we can find a date
        possible_date = nil

        # Skip over the first block of text but overlap a bit. We don't scan
        # The entire document because the parsers can hang. Usually the relevant
        # date is within the first 200 words though.
        text = extracted_text.gsub(/\n/, " ").gsub(/ +/, ' ').split(" ")[25..200].join(" ")
        text = text.gsub(street_name_regex, '')

        # Sometimes dates bump right up with other text 6/29/2011Date Prepared
        # which can throw off the parsers
        match = nil
        match = text.match(/(\/|-|_|\.)\d{4}/)
        unless match.nil?
          text = text.gsub(/(\/|-|_|\.)\d{4}/, match[0]+" ")
        end

        possible_date = Document.parse_date(text)

        # The format of the date can be way off, so we check to see if it is in the
        # future or way in the past
        unless
          (possible_date.to_datetime > 6.months.from_now.to_datetime) ||
          (possible_date.to_datetime < 50.years.ago.to_datetime)

          # This could also be a candidate so we'll add it to the likely_dates
          third_possible_date = possible_date
          likely_dates[:third_date] = third_possible_date
        end
      rescue
        # Ignore
      end
    end

    #################
    # HOLY HELL --- FIGURE OUT WHICH DATE WE'RE ACTUALLY GOING TO SEND BACK
    #################

    # FIRST BEST: Duplicates of the same date likely mean that we've found the right date
    if !first_possible_date.nil? && !second_possible_date.nil? && (first_possible_date == second_possible_date)
      return first_possible_date
    elsif !first_possible_date.nil? && !third_possible_date.nil? && (first_possible_date == third_possible_date)
      likely_date = first_possible_date
    end

    # SECOND BEST: The date we found in the URL are usually pretty good
    if likely_date.nil? && !first_possible_date.nil?
      likely_date = first_possible_date
    end

    # THIRD BEST:
    if likely_date.nil? && first_possible_date.nil? && !second_possible_date.nil?
      likely_date = second_possible_date
    end

    # FOURTH BEST: If the second_date is between the first and third
    if likely_date.nil? && !first_possible_date.nil? && !third_possible_date.nil?
      range = first_possible_date..third_possible_date
      if range === second_possible_date
        likely_date = second_possible_date
      end
    end

    # FIFTH BEST: Sort the dates and use the oldest
    if likely_date.nil? && likely_dates.size > 0
      likely_date = likely_dates.sort.reverse.first[1]
    end

    # SIXTH BEST: Try one last time
    if likely_date.nil? && !extracted_text.nil?
      text = extracted_text.downcase.gsub(/\n/, " ").gsub(/ +/, ' ').split(" ")[0..500].join(" ")
      dates = text.scan(/\d{0,4}-\d{0,4}-\d{0,4}/)
      dates.each do |possible_date|
        begin
          likely_date = Document.parse_date(possible_date)
        rescue
          # Ignore
        end
      end
    end

    # The HTTP Last Modified isn't always available and even then
    # sometimes it's way off but we can use it to compare against the likely_dates
    # A date that we find in the document should be pretty close to the last_modified
    if !last_modified.nil? && likely_dates.size > 0
      days_apart = (likely_date - last_modified).abs.floor

      # Check to see if there are any other likely dates that are closer
      # to the last_modified than what we have currently selected
      likely_dates.each do |key, value|
        temp_days_apart = (last_modified - value).abs.floor

        # A date that is closer to the last_modified
        if temp_days_apart < days_apart
          days_apart = temp_days_apart
          likely_date = value
        end
      end
    end

    # Perform one last sanity check on the date that we got. If it's in the future
    # it's probably not the date that we want.
    unless !likely_date.nil? && likely_date.to_datetime > 6.months.from_now.to_datetime
      return likely_date

    # Cry, give up and go home, we really can't find a date.
    # Time sucks. It can't be real: http://en.wikipedia.org/wiki/Time
    # But return our best guess
    else
      return nil
    end
  end

  # Parse a date of unknown format.
  # Optionally, you can pass in a "short_form" to suggest potential characteristics expected.
  # It will be used to determine if the date is international format, or US formatted
  # (Note: Date separators don't matter with short dates, they will be stripped out)
  def self.parse_date( date_string, options={} )
    date = nil
    short_form = options[:short_form]

    if(day_before_month?(short_form))
      # Normalize separators
      shorted_date_string = date_string.gsub(/[\.-]/,"/")
      shorted_short_form = short_form.gsub(/[\.-]/,"/")

      if(long_year?(date_string))
        date ||= Date.strptime(shorted_date_string, shorted_short_form.gsub(/\%y/,"\%Y")) rescue nil
      else
        date ||= Date.strptime(shorted_date_string, shorted_short_form.gsub(/\%Y/, "\%y")) rescue nil
      end
    end
    date ||= Chronic.parse(date_string).to_date rescue nil
    date ||= Date.parse(date_string) # allow this exception through if we can't parse at all
    date
  end

  private

  # determine if this is an international date format (day before month before year)
  def self.day_before_month?(short_form)
    return false if short_form.nil?
    (/\%d/i =~ short_form) < (/\%m/i =~ short_form)
  end

  # Figure out if we have a long (4 digit) year
  def self.long_year?(date)
    # if no spaces...
    if(date.strip.index(' ').nil?)
      # split on -, /, or . (valid separators for dates I guess.)
      parts = date.split(/[-\/\.]/)
      # if the first bit, or last bit if 4 chars
      (parts.first.size == 4) || (parts.last.size == 4)
    end
  end
end
