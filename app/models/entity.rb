class Entity < ActiveRecord::Base
  belongs_to :document
  has_many :instances, :dependent => :delete_all

  attr_accessible :kind,
                  :guid,
                  :name,
                  :commonname,
                  :reference_type,
                  :organization_kind,
                  :person_kind,
                  :nationality

  validates :name, :length_truncate => { :maximum => 255 }
end
