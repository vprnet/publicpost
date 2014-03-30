class CreateApiKeys < ActiveRecord::Migration
  def change
    create_table :api_keys do |t|
      t.string :access_token
      t.string :name
      t.string :email
      t.timestamp :expires_at

      t.timestamps
    end
  end
end
