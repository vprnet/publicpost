class AddLocationPeopleOrganizationToDocument < ActiveRecord::Migration
  def change
    change_table :documents do |t|
      t.text :people
      t.text :locations
      t.text :organizations
    end
  end
end
