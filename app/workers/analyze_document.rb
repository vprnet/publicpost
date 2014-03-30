# Job that classifies, dates, and determines the organization for a Document.
class AnalyzeDocument < Worker

  sidekiq_options queue: "medium"
  sidekiq_options :retry => false

  # Task implementation.
  #
  # @param arg Argument used by the task
  def run(arg)
    document = Document.unscoped.find(arg)

    document.classification = document.guess_classification
    document.likely_date = document.find_likely_dates
    document.legislative_body = document.determine_owning_organization
    document.people = document.named_people
    document.locations = document.named_locations
    document.organizations = document.named_organizations
    document.terms = document.guessed_terms
    document.save!
  end
end
