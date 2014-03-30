class ApplicationController < ActionController::Base
  protect_from_forgery

  def user_for_paper_trail
    if current_user.nil?
      request.remote_ip
    else
      current_user
    end
  end

  def info_for_paper_trail
    { :ip => request.remote_ip, :user_agent => request.user_agent }
  end 

end