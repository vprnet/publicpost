require 'roar/representer/json'
require 'roar/representer/feature/hypermedia'
require_relative 'entity_representer'

module V1
  module DocumentRepresenter
    include ApplicationHelper
    include Roar::Representer::JSON
    include Roar::Representer::Feature::Hypermedia

    property :api_version

    property :guid
    link :self do
      api_v1_document_url self.guid
    end

    link :municipality do
      api_v1_municipality_url municipality
    end
    property :municipality_name
    property :municipality_state
    property :municipality_slug

    property :content_url

    property :created_at
    property :updated_at
    property :last_modified
    property :content_type

    property :likely_date
    property :classification

    property :legislative_body
    property :status

    property :people
    property :organizations
    property :locations

    property :title
    property :summary
    property :extracted_text

    def api_version
      "v1"
    end

    def summary
      safe_squeeze(extracted_text[0..300]) unless extracted_text.nil?
    end

    def municipality_name
      municipality.name
    end

    def municipality_state
      municipality.state
    end

    def municipality_slug
      municipality.slug
    end
  end
end