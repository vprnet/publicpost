class AddUsefulToDocument < ActiveRecord::Migration
  def change     
    add_column :documents, :useful, :boolean
  end
end
