module V1
  class DocumentsController < V1::BaseController
    include Roar::Rails::ControllerAdditions
    before_filter :authenticate_user!, :only => [:create_classifications, :update_classifications]
    respond_to :json

    def index
      options = {}
      options.merge!({ :content_type => params[:content_type] }) unless params[:content_type].blank?
      options.merge!({ :classification => params[:classification] }) unless params[:classification].blank?
      options.merge!({ :legislative_body => params[:legislative_body] }) unless params[:legislative_body].blank?
      options.merge!({ :municipality_id => params[:municipality_id] }) unless params[:municipality_id].blank?

      if !params[:municipality_slug].blank?
        municipalities = Municipality.where(:slug => params[:municipality_slug].downcase)
        options.merge!(:municipality_id => municipalities.map {|municipality| municipality.id})
      elsif !params[:state].blank?
        municipalities = Municipality.where(:state => params[:state].upcase).select("id")
        options.merge!(:municipality_id => municipalities.map {|municipality| municipality.id})
      end

      begin
        created_after = DateTime.parse params[:created_after] unless params[:created_after].blank?
        created_before = DateTime.parse params[:created_before] unless params[:created_before].blank?

        updated_after = DateTime.parse params[:updated_after] unless params[:updated_after].blank?
        updated_before = DateTime.parse params[:updated_before] unless params[:updated_before].blank?

        deleted_after = DateTime.parse params[:deleted_after] unless params[:deleted_after].blank?
        deleted_before = DateTime.parse params[:deleted_before] unless params[:deleted_before].blank?
      rescue
        errors = {"error" => "Invalid date format. Should be like: 2012-07-08T18:54:22-04:00 or 2012-07-08."}
      end

      if !created_after.nil? && created_before.nil?
        created_before = DateTime.now
      end
      if !created_after.nil? && !created_before.nil?
        options.merge!(:created_at => created_after..created_before)
      end

      if !updated_after.nil? && updated_before.nil?
        updated_before = DateTime.now
      end
      if !updated_after.nil? && !updated_before.nil?
        options.merge!(:updated_at => updated_after..updated_before)
      end

      include_deleted = false
      if !deleted_after.nil? && deleted_before.nil?
        deleted_before = DateTime.now
      end
      if !deleted_after.nil? && !deleted_before.nil?
        include_deleted = true
        options.merge!(:deleted_at => deleted_after..deleted_before)
      end

      sort_by = params[:sort_by]
      if sort_by.blank?
        sort_by = "created_at"
      end

      sort_criteria = sort_by.split(':')
      sort_column   = sort_criteria.first
      sort_order    = sort_criteria.length > 1 ? sort_criteria[1] : ''
      if sort_order != 'asc' && sort_order != 'desc'
        sort_order = 'desc'
      end

      if include_deleted
        documents = Document.with_deleted.where(options)
      else
        documents = Document.where(options)
      end
      documents = documents.order("documents.#{sort_column} #{sort_order} nulls last").includes(:municipality).paginate(:page => params[:page], :per_page => params[:per_page])
      documents.extend(V1::DocumentsRepresenter)

      respond_to do |format|
        if errors
          format.json { render :json => errors.to_json, :status => 500 }
        else
          query_string = request.GET.to_hash.except!("page")
          format.json {
            render :json => documents.to_json(
              :per_page => params[:per_page],
              :query_string => query_string
            )
          }
        end
      end
    end

    def show
      document = Document.find_by_guid(params[:id])
      respond_with document, :represent_with => V1::DocumentRepresenter
    end

    def update
      document = Document.find_by_guid(params[:id])
      unless document.nil?
        document.update_attributes(params)
        render  :status => 200,
                :text => "{ 'ok' : true , 'guid' : '#{document.guid}''}"
      else
        raise ActionController::RoutingError.new('Not Found')
      end
    end

    def classifications
      classifications = Document.all(:select => 'distinct(classification)')
      classifications.delete_if {|x| x.classification == nil }
      classifications.sort! { |a,b| a.classification.downcase <=> b.classification.downcase }
      render :text => classifications.to_json
    end

    def content_types
      content_types = Document.all(:select => 'distinct(content_type)')
      content_types.delete_if {|x| x.content_type == nil }
      content_types.sort! { |a,b| a.content_type.downcase <=> b.content_type.downcase }
      render :text => content_types.to_json
    end

    def legislative_bodies
      legislative_bodies = Document.all(:select => 'distinct(legislative_body)')
      legislative_bodies.delete_if {|x| x.legislative_body == nil }
      legislative_bodies.sort! { |a,b| a.legislative_body.downcase <=> b.legislative_body.downcase }
      render :text => legislative_bodies.to_json
    end

    def search
      query = params[:q]
      search = Tire::Search::Search.new('documents')
      search.query { string("#{query}") }
      search.sort { by :updated_at, 'desc' }
      search.facet('likely_date') { date :likely_date, :interval => 'month' }
      search.facet('classification') { terms :classification, :global => false }
      search.facet('legislative_body') { terms :legislative_body, :global => false }
      search.facet('municipality_state') { terms :municipality_state, :global => false }
      search.facet('municipality_slug') { terms :municipality_slug, :global => false }
      search.facet('content_type') { terms :content_type, :global => false }

      begin
        respond_to do |format|
          format.json { render :text => search.results.to_json }
        end
      rescue
        respond_to do |format|
          format.json {
            render :status => 500,
            :text => '{ "error" : "Sorry but search is unavailable at the moment." }' }
        end
      end
    end

  end
end