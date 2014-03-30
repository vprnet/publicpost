require 'roar/representer/json'
require 'roar/representer/feature/hypermedia'

module V1
  module EntityRepresenter
    include Roar::Representer::JSON
    include Roar::Representer::Feature::Hypermedia

    property :name

    def value
      name
    end
  end
end