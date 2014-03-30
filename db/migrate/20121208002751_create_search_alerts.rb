class CreateSearchAlerts < ActiveRecord::Migration
  def change
    create_table :search_alerts do |t|

      # Search querystring
      t.string :querystring

      # Email address for the recipient of the alert
      t.string :recipient_email

      # Name of the recipient of the alert
      t.string :recipient_name

      t.timestamps
    end
  end
end
