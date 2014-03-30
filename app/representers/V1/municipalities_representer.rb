require 'roar/representer/json'
require 'roar/representer/feature/hypermedia'
require_relative 'municipality_representer'

module V1
  module MunicipalitiesRepresenter
    include Roar::Representer::JSON
    include Roar::Representer::Feature::Hypermedia

    property :total_entries
    property :per_page
    collection :municipalities, :extend => MunicipalityRepresenter

    def municipalities
      self
    end
  end
end