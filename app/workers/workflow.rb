# Main document workflow.
class Workflow

  # State transition: begin crawling the website for the given Municipality slug.
  def self.start_crawl_municipality(arg)
    CrawlMunicipality.perform_async(arg, "Workflow.end_crawl_municipality(arg)")
  end

  # State transition: end crawling the website for the given Municipality slug.
  def self.end_crawl_municipality(arg)
    # Do nothing for now
  end

  # State transition: begin processing the Document with the given identifier.
  def self.start_process_document(arg)
    start_extract_text(arg)
    UploadDocument.perform_async(arg, nil) if Rails.env.production?
  end

  # State transition: end processing the Document with the given identifier.
  def self.end_process_document(arg)
    # Mark the document as processed
    document = Document.unscoped.find(arg)
    document.state = Document::PROCESSED
    document.save!
  end

  # State transition: begin extracting text from the Document with the given identifier.
  def self.start_extract_text(arg)
    ExtractTextFromDocument.perform_async(arg, "Workflow.end_extract_text(arg)")
  end

  # State transition: end extracting text from the Document with the given identifier.
  def self.end_extract_text(arg)
    start_extract_meaning(arg)
  end

  # State transition: begin extracting meaning from the Document with the given identifier.
  def self.start_extract_meaning(arg)
    ExtractMeaningFromDocument.perform_async(arg, "Workflow.end_extract_meaning(arg)")
  end

  # State transition: end extracting meaning from the Document with the given identifier.
  def self.end_extract_meaning(arg)
    start_analyze_document(arg)
  end

  # State transition: begin analyzing the Document with the given identifier.
  def self.start_analyze_document(arg)
    AnalyzeDocument.perform_async(arg, "Workflow.end_analyze_document(arg)")
  end

# State transition: end analyzing the Document with the given identifier.
  def self.end_analyze_document(arg)
    end_process_document(arg)
  end
end
