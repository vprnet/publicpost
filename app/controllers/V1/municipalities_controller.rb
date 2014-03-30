module V1
  class MunicipalitiesController < V1::BaseController
    include Roar::Rails::ControllerAdditions
    respond_to :json

    def index
      options = {}
      options.merge!({ :state => params[:state].upcase }) unless params[:state].blank?

      municipalities = Municipality.where(options).paginate(:page => params[:page], :per_page => params[:per_page])
      municipalities.extend(V1::MunicipalitiesRepresenter)

      respond_to do |format|
        format.json { render :json => municipalities.to_json }
      end
    end

    def show
      municipality = Municipality.find_by_slug(params[:id])
      respond_with municipality, :represent_with => V1::MunicipalityRepresenter
    end
  end
end