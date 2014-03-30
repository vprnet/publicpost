class SearchAlertsController < ApplicationController  
  
  def index
    @alert = SearchAlert.new
  end

  def update
    @alert = SearchAlert.find params[:id]

    respond_to do |format|
      if @alert.update_attributes(params[:search_alert])
        format.html { redirect_to(@alert, :notice => 'Alert was successfully updated.') }
        format.json { respond_with_bip(@alert) }
      else
        format.html { render :action => "edit" }
        format.json { respond_with_bip(@alert) }
      end
    end
  end

  def create
    @alert = SearchAlert.new(params[:search_alert])
    @alert.user = current_user
    if @alert.save
      redirect_to :action => "index"
    else
      # This line overrides the default rendering behavior, which
      # would have been to render the "create" view.
      redirect_to :action => "index"
    end
  end

  def destroy
    SearchAlert.find(params[:id]).destroy
    redirect_to :action => 'index'
  end

end