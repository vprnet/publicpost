# Job that updates document entities. Note: It does not update updated_at.
class UpdateDocumentEntities < Worker

  sidekiq_options queue: "medium"

  # Task implementation.
  #
  # @param arg Argument used by the task
  def run(arg)
    document = Document.unscoped.find(arg)
    document.people = document.named_people
    document.locations = document.named_locations
    document.organizations = document.named_organizations
    document.terms = document.guessed_terms
    document.update_record_without_timestamping
  end
end
