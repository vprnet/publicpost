class SearchAlert < ActiveRecord::Base

  belongs_to :user

  attr_accessible :querystring

  validates :querystring, :user, :presence => true

  def self.send_alerts

    SearchAlert.where("querystring is not null").each do |alert|
      per_page = 20
      if !alert.querystring.blank?
        s = Tire.search 'documents' do
          query do
            string alert.querystring, :default_operator => 'AND'
          end
          highlight 'extracted_text', options: { :tag => '***', :fragment_size => 500 }
          size per_page
          filter :range, :created_at => { :gte => 1.day.ago }
        end

        results_counter = 1
        if s.results.size > 0
          text = "Your search for: #{alert.querystring}\n\n"
          s.results.each do |doc|
            text += "\n"
            text += "-------------------------------\n"
            text += "Match #{results_counter} :: #{doc.municipality_name}, #{doc.municipality_state}\n"
            text += "-------------------------------\n"
            unless doc.highlight.nil? || doc.highlight.extracted_text.nil?
              text += "#{doc.highlight.extracted_text[0].gsub(/\s/, ' ').squeeze(" ").strip}\n"
            end
            unless doc.extracted_text.nil?
              text += "#{doc.extracted_text.split(" ")[0..50].join(" ")}\n"
            end
            text += "Original Url:   #{doc.content_url}\n"
            text += "HSSS Url:       http://#{ENV['HSSS_MAILER_HOST']}/documents/#{doc.guid}\n"
            text += "Classification: #{doc.classification.humanize}\n"
            text += "Organization:   #{doc.legislative_body.humanize}\n\n"
            results_counter += 1
          end

          text += "Thanks,\n"
          text += "Your Municipal Search Robot"

          subject = "Municipal document alert: #{alert.querystring}"

          email_data = {
              "from"          => "publicpost@vpr.net",
              "to"            => "#{alert.user.email}",
              "subject"       => subject,
              "text"          => text
          }

          http_client = HTTPClient.new
          http_client.set_auth(Constants::MAILGUN_URL, 'api', Constants::MAILGUN_API_KEY)
          http_client.post(Constants::MAILGUN_URL + "/messages", email_data)
        end
      end
    end
  end

end
