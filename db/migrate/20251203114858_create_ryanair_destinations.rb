class CreateRyanairDestinations < ActiveRecord::Migration[8.0]
  def change
    create_table :ryanair_destinations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :seo_name
      t.string :city_name
      t.string :city_code
      t.string :country_name
      t.string :country_code
      t.string :currency_code
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :timezone
      t.boolean :is_base, default: false
      t.boolean :seasonal, default: false
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :ryanair_destinations, :code, unique: true
  end
end
