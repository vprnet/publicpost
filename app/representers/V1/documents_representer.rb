require 'roar/representer/json'
require 'roar/representer/feature/hypermedia'
require_relative 'light_document_representer'

module V1
  module DocumentsRepresenter
    include Roar::Representer::JSON
    include Roar::Representer::Feature::Hypermedia
    
    property :total_entries
    property :per_page

    link :self do |opts|
      opts[:query_string].merge!({:page => current_page})
      api_v1_documents_url(opts[:query_string])
    end

    link :next do |opts|
      opts[:query_string].merge!({:page => next_page})
      api_v1_documents_url(opts[:query_string]) if next_page
    end
   
    link :previous do |opts|
      opts[:query_string].merge!({:page => previous_page})
      api_v1_documents_url(opts[:query_string]) if previous_page
    end

    collection :documents, :extend => LightDocumentRepresenter

    def documents
      self
    end
  end 
end