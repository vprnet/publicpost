require 'roar/representer/json'
require 'roar/representer/feature/hypermedia'

module V1
  module MunicipalityRepresenter
    include Roar::Representer::JSON
    include Roar::Representer::Feature::Hypermedia

    link :self do
      municipality_url self
    end

    link :documents do
      api_v1_documents_url(:municipality_slug => slug)
    end

    property :state
    property :full_name
    property :slug
    property :website
  end
end