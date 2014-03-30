class SessionsController < ApplicationController
  def new
  end

  def create
    session[:password] = params[:password]
    flash[:notice] = "Successfully logged in"
    redirect_to :root
  end
  
  def destroy
    reset_session
    flash[:notice] = "Successfully logged out"
    redirect_to :root
  end
end