class CreateEntities < ActiveRecord::Migration
  def change
    create_table :entities do |t|
      t.string :guid
      t.string :kind
      t.string :name
      t.string :commonname
      t.string :reference_type
      t.string :organization_kind
      t.string :person_kind
      t.string :nationality

      t.references :document
      t.timestamps
    end

    add_index(:entities, :document_id)
    add_index(:entities, :kind)
  end
end
