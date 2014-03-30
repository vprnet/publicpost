class PeopleController < ApplicationController

  def show
    person_guid = Base64.urlsafe_decode64(params[:id])
    @person = Entity.find_by_guid(person_guid)
  end
end
