# Job that extracts text from a Document.
class ExtractTextFromDocument < Worker

  sidekiq_options queue: "high"
  sidekiq_options :retry => 10

  # Task implementation.
  #
  # @param arg Argument used by the task
  def run(arg)
    document = Document.unscoped.find(arg)

    # Extract text from the given Document using the text-extractor service(s).
    url = Constants::TEXT_EXTRACTOR_URLS[Random.rand(Constants::TEXT_EXTRACTOR_URLS.length)] + "/extract?url=" + CGI::escape(document.content_url)
    response = @@http_client.get(url, :follow_redirect => true)
    if response.ok?
      text = safe_squeeze(response.body)
      if !text.nil? && text.length > 0
        document.extracted_text = text
        document.save!
      end
    else
      raise StandardError, "Text extraction service error: (#{response.code})"
    end
  end
end
