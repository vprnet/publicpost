class DocumentsController < ApplicationController

  def index
    options = {}
    options.merge!({ :content_type => params[:content_type] }) unless params[:content_type].blank?
    options.merge!({ :classification => params[:classification] }) unless params[:classification].blank?
    options.merge!({ :legislative_body => params[:organization] }) unless params[:organization].blank?
    options.merge!({ :content_url => URI::encode(params[:content_url]) }) unless params[:content_url].blank?

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

    @documents = Document.order("#{sort_column} #{sort_order} nulls last").where(options).paginate(:page => params[:page], :per_page => params[:per_page])
  end

  def show
    @document = Document.find_by_guid(params[:id])
  end

  def new
    @document = Document.new
  end

  def update
    @document = Document.find(params[:id])

    respond_to do |format|
      if @document.update_attributes(params[:document])
        format.html { redirect_to(@document, :notice => 'Document was successfully updated.') }
        format.json { respond_with_bip(@document) }
      else
        format.html { render :action => 'edit' }
        format.json { respond_with_bip(@document) }
      end
    end
  end

  def search
    query = params[:q]

    page_number = (params[:page] || 1)
    per_page = (params[:per_page] || 10)

    date_range_match = query.match(/\s(past:)(\d+)/)
    published_date_range_match = query.match(/\s(published_past:)(\d+)/)

    # Determine if we need to remove the date range filters
    query = query.gsub(/\s(past:)(\d+)/, '')
    query = query.gsub(/\s(published_past:)(\d+)/, '')
    params[:q] = query

    if !query.blank?

      #begin
        search = Tire::Search::Search.new('documents')

        search.size(per_page)
        search.from(page_number)

        search.query { string("#{query}", :default_operator => 'AND') }

        search.facet('municipality_state') { terms :municipality_state }
        search.facet('classification') { terms :classification }
        search.facet('legislative_body') { terms :legislative_body }

        unless date_range_match.nil?
          number = date_range_match[2].to_i
          search.filter :range, :created_at => { :gte => number.days.ago }
        end
        unless published_date_range_match.nil?
          number = published_date_range_match[2].to_i
          search.filter :range, :likely_date => { :gte => number.days.ago, :lte => number.days.from_now }
        end

        search.highlight 'extracted_text', options: { tag: '<strong>', fragment_size: 300 }

        @documents = search.results
        @facets = search.results.facets

        puts search.to_curl

        render :action => 'search'
      #rescue Exception => e
      #  puts "!!!! Error: #{e.message}"
      #  redirect_to :controller => 'static_pages', :action => 'home'
      #end
    else
      redirect_to :controller => 'static_pages', :action => 'home'
    end
  end

  def train_meeting
    classification = params[:classification]
    document = Document.find_by_guid(params[:id])
    document.train_meeting(classification)
    guid = document.previous_document.guid
    redirect_to "/documents/#{guid}"
  end

  def train_legislative_body
    classification = params[:classification]
    document = Document.find_by_guid(params[:id])
    document.train_legislative_body(classification)
    guid = document.previous_document.guid
    redirect_to "/documents/#{guid}"
  end

  def process_document
    document = Document.find_by_guid(params[:id])
    Workflow.start_process_document(document.id)
    redirect_to "/documents/#{params[:id]}"
  end
end
