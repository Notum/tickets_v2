class CreateNorwegianDestinations < ActiveRecord::Migration[8.0]
  def change
    create_table :norwegian_destinations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :city_name
      t.string :country_name
      t.boolean :active, default: true, null: false
      t.datetime :announced_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :norwegian_destinations, :code, unique: true
  end
end
