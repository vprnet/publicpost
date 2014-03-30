class UsersController < ApplicationController
  def index
    @users = User.order(:last_sign_in_at).paginate(:page => params[:page], :per_page => params[:per_page])
  end

  def show
    @user = User.find(params[:id])
    @docs_edited = Version.where(:whodunnit => @user.id.to_s).where(:item_type => "Document").paginate(:page => params[:page], :per_page => params[:per_page])
  end
end