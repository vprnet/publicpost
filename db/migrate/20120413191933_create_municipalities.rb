# see http://developer.usatoday.com/docs/read/Census
class CreateMunicipalities < ActiveRecord::Migration
  def change
    create_table :municipalities do |t|
      # Municipality name
      # e.g. Somerville
      t.string :name

      # State
      # e.g. MA
      t.string :state

      # Human-readable ID
      # e.g. somerville-ma
      t.string :slug

      # Municipality website
      # e.g. http://www.somervillema.gov
      t.string :website

      # Determine if cookies should be accepted and subsequently provided
      # during a website crawl
      t.boolean :website_accept_cookies

      # Space-deliminted list of externally linkable domains. Referenced resources
      # from these domains will be processed but not crawled further; they are
      # considered to be terminals
      # e.g. http://www.foo.com http://www.bar.com
      t.string :website_linkable_domains

      # Space-delimited regular expressions for website links to skip
      # e.g. ^/Calendar/ AddEvent.aspx
      t.string :website_skip_links

      # Space-delimited regular expressions for website link query parameters to
      # eliminate
      # e.g. ^id session_
      t.string :website_strip_params

      # Federal Information Processing Standards and Geographic Names Information System codes
      # e.g. 2501762535, 62535
      t.string :code_fips
      t.string :code_gnis

      # Total population
      # e.g. 75754
      t.integer :population

      # Number of people per square mile of land area
      # e.g. 18403.9
      t.float :population_density

      # Racial classification (in percentages)
      t.float :race_american_indian
      t.float :race_asian
      t.float :race_black
      t.float :race_hispanic
      t.float :race_multiple
      t.float :race_non_hispanic
      t.float :race_non_hispanic_white
      t.float :race_other
      t.float :race_pacific_islander
      t.float :race_white

      # Probability that two randomly chosen people will have different racial backgrounds
      # e.g. 0.480113
      t.float :diversity

      # Number of square miles of land/water
      # e.g. 4.1, 0.1
      t.float :area_land
      t.float :area_water

      # Latitude and longitude coordinates for center point of the municipality
      # e.g. 42.3905662, -71.1013245
      t.float :latitude
      t.float :longitude

      # Housing units (total and vacant)
      # e.g. 33720, 1615
      t.integer :housing_units
      t.integer :housing_vacancies

      t.timestamps
    end

    add_index(:municipalities, :name)
    add_index(:municipalities, :state)
    add_index(:municipalities, :slug)
    add_index(:municipalities, :website)
    add_index(:municipalities, [:latitude, :longitude])
  end
end
