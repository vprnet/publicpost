class AddDisplayNameToMunicipalities < ActiveRecord::Migration
  def self.up
    add_column :municipalities, :display_name, :string
  end

  def self.down
    remove_column :municipalities, :display_name
  end
end
