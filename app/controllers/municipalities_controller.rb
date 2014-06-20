# see https://github.com/mislav/will_paginate/issues/154
require 'will_paginate/array'

class MunicipalitiesController < ApplicationController

  def index
    @municipalities = Municipality.all(order: "name asc", conditions: "state = 'VT' and website != ''").paginate(page: params[:page], :per_page => 2000)
    @states = @municipalities.group_by(&:state).keys
  end

  def show
    @municipality = Municipality.find_by_slug(params[:id])

    options = {}
    options.merge!({ :content_type => params[:content_type] }) unless params[:content_type].blank?
    options.merge!({ :classification => params[:classification] }) unless params[:classification].blank?
    options.merge!({ :legislative_body => params[:organization] }) unless params[:organization].blank?
    sort_column = "documents.created_at"
    sort_column = params[:sort_by] unless params[:sort_by].blank?
    params[:per_page] = 5

    @documents = @municipality.documents.order("#{sort_column} desc nulls last").where(options).paginate(:page => params[:page], :per_page => params[:per_page])
  end

  def documents
    @municipality = Municipality.find_by_slug(params[:id])
  end

  def states
    @state = params[:state].nil? ? nil : params[:state].upcase
    @municipalities = Municipality.where(:state => @state)

    options = {}
    options.merge!({ :content_type => params[:content_type] }) unless params[:content_type].blank?
    options.merge!({ :classification => params[:classification] }) unless params[:classification].blank?
    options.merge!({ :legislative_body => params[:organization] }) unless params[:organization].blank?
    sort_column = "documents.created_at"
    sort_column = params[:sort_by] unless params[:sort_by].blank?

    classification = params[:classification] unless params[:classification].blank?
    @documents = Document.includes(:municipality).where(:municipality_id => @municipalities.map {|municipality| municipality.id}).order("#{sort_column} desc nulls last").where(options).paginate(:page => params[:page])

  end
end
