class CreateStates < ActiveRecord::Migration
  def change
    create_table :states do |t|
      t.string :code
      t.string :full_name

      t.timestamps
    end
  end
end
