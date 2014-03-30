class AddLastCrawlDateToMunicipality < ActiveRecord::Migration
  def change
    add_column :municipalities, :last_crawl_date, :datetime
  end
end
