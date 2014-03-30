class AddUserAssociationToSearchAlert < ActiveRecord::Migration
  def change
    add_column :search_alerts, :user_id, :integer
  end
end
