class Municipality < ActiveRecord::Base

  validates :name,  presence: true
  validates :state, presence: true
  validates :slug,  presence: true

  validates :population,         numericality: { greater_than_or_equal_to: 0 }
  validates :population_density, numericality: { greater_than_or_equal_to: 0.0 }

  validates :race_american_indian,    numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_asian,              numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_black,              numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_hispanic,           numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_multiple,           numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_non_hispanic,       numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_non_hispanic_white, numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_other,              numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_pacific_islander,   numericality: { greater_than_or_equal_to: 0.0 }
  validates :race_white,              numericality: { greater_than_or_equal_to: 0.0 }

  validates :diversity, numericality: { greater_than_or_equal_to: 0.0 }

  validates :area_land,  numericality: { greater_than_or_equal_to: 0 }
  validates :area_water, numericality: { greater_than_or_equal_to: 0 }

  validates :latitude,  presence: true
  validates :longitude, presence: true

  validates :housing_units,     numericality: { greater_than_or_equal_to: 0 }
  validates :housing_vacancies, numericality: { greater_than_or_equal_to: 0 }

  attr_accessible :website, :website_linkable_domains

  has_many :documents, :dependent => :delete_all

  # Return the ID used to refer to this Municipality.
  #
  # @return [String] the ID used to refer to this Municipality
  def to_param
    slug
  end

  # Return a human-readable name for this Municipality.
  #
  # @return [String] a human-readable name for this Municipality
  def full_name
    "#{display_name.nil? ? name : display_name}, #{state}"
  end

  # Return a slug (human-readable ID) for a given Municipality name and state.
  #
  # @return [String] a slug for the given Municipality name and state
  def self.create_slug(name, state)
    slug_name  = name.downcase.gsub(/[^[:alnum:]]/,'-').gsub(/-{2,}/,'-')
    slug_state = state.downcase
    "#{slug_name}-#{slug_state}"
  end

  # Returns the popular topics for this Municipality.
  #
  # @param [Integer] limit The number of topics to return. Default is 10.
  #
  # @return [Array] Popular topics as an array of Entities
  def popular_topics(limit = 10)
    Entity.joins(:document).where(:documents => {:municipality_id => self.id}).where(:kind => "IndustryTerm").limit(limit).group_by(&:name)
  end

  # Returns the people often mentioned in the Municipality.
  #
  # @param [Integer] limit The number of people to return. Default is 10.
  #
  # @return [Array] Popular people as an array of Entities
  def people_often_mentioned(limit = 10)
    Entity.joins(:document).where(:documents => {:municipality_id => self.id}).where(:kind => "Person").limit(limit).group_by(&:name)
  end

  # Returns all people mentioned in the Municipality.
  #
  # @return [Array] People as an array of Entities
  def people
    entities_by_kind(:kind => "Person")
  end

  # Returns all Entites of the specified type.
  #
  # @return [Array] Entities of the given type or all Entities if no kind is
  #                 specified.
  def entities_by_kind(args = { })
    kind  = args[:kind]
    limit = args[:limit]
    if kind.nil?
      Entity.joins(:document).where(:documents => {:municipality_id => self.id}).limit(limit)
    else
      Entity.joins(:document).where(:documents => {:municipality_id => self.id}).where(:kind => kind).limit(limit)
    end
  end
end
