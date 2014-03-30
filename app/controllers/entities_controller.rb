class EntitiesController < ApplicationController
  before_filter :authenticate_user!

  def index
    @organizations = Entity.where(:kind => "Organization").order("count_all DESC").limit(50).count(:group => [:name])
    @people = Entity.where(:kind => "Person").order("count_all DESC").limit(50).count(:group => [:name])
    @companies = Entity.where(:kind => "Company").order("count_all DESC").limit(50).count(:group => [:name])
  end

  def show
    @name = params[:id].gsub('-', ' ').downcase

    @entities = Entity.includes(:document).where("lower(name) = ?", @name).group_by(&:guid)
    @places = Document.joins(:municipality).joins(:entities).where("lower(entities.name) = ?", @name).group_by(&:municipality)
    @documents = Document.joins(:entities).where("lower(entities.name) = ?", @name).order(:likely_date).reverse
  end
end