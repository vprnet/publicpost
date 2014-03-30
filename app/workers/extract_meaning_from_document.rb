# Job that extracts text from a Document.
class ExtractMeaningFromDocument < Worker

  sidekiq_options queue: "medium"
  sidekiq_options :retry => 2

  # Task implementation.
  #
  # @param arg Argument used by the task
  def run(arg)
    # No-op for now. Stop Giving Open Calais our documents.
    # Speeds things up for now but we need to replace it with our own
  end
end
