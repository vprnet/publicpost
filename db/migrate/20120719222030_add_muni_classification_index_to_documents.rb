class AddMuniClassificationIndexToDocuments < ActiveRecord::Migration
  def change
  	add_index :documents, [:municipality_id, :classification]
  end
end
