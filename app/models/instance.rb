class Instance < ActiveRecord::Base

  belongs_to :entity

  attr_accessible :detection,
                  :prefix,
                  :exact,
                  :suffix,
                  :offset,
                  :length,
                  :relevance
end
