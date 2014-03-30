class AddTermsToDocument < ActiveRecord::Migration
  def change
    change_table :documents do |t|
      t.text :terms
    end
  end
end
