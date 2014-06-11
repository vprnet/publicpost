class RenameDocumentsPersistedUrl < ActiveRecord::Migration
  def up
    rename_column :documents, :persisted_url, :hsss_persisted_url
    add_column :documents, :persisted_url, :string
  end

  def down
    remove_column :documents, :persisted_url
    rename_column :documents, :hsss_persisted_url, :persisted_url
  end
end
