class CreateAirbalticDestinations < ActiveRecord::Migration[8.0]
  def change
    create_table :airbaltic_destinations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :city_name
      t.string :country_name
      t.string :country_code
      t.datetime :announced_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :airbaltic_destinations, :code, unique: true
  end
end
