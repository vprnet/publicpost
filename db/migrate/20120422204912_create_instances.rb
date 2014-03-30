class CreateInstances < ActiveRecord::Migration
  def change
    create_table :instances do |t|
      t.text :detection
      t.text :prefix
      t.text :exact
      t.text :suffix
      t.integer :offset
      t.integer :length
      t.float :relevance

      t.references :entity
      t.timestamps
    end
  end
end
