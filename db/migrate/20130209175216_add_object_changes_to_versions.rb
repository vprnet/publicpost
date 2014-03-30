class AddObjectChangesToVersions < ActiveRecord::Migration
  change_table :versions do |t|
    t.text :object_changes
  end
end
