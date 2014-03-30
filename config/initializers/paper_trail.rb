# config/initializers/paper_trail.rb
class Version < ActiveRecord::Base
  attr_accessible :ip, :user_agent
end