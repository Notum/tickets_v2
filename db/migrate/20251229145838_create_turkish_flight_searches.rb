class CreateTurkishFlightSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :turkish_flight_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :destination_code, null: false
      t.string :destination_name, null: false
      t.string :destination_city_code
      t.string :destination_country_code
      t.date :date_out, null: false
      t.date :date_in, null: false
      t.decimal :price_out, precision: 10, scale: 2
      t.decimal :price_in, precision: 10, scale: 2
      t.decimal :total_price, precision: 10, scale: 2
      t.boolean :is_direct_out, default: false
      t.boolean :is_direct_in, default: false
      t.string :status, default: "pending"
      t.text :api_response
      t.datetime :priced_at

      t.timestamps
    end

    add_index :turkish_flight_searches, [:user_id, :destination_code, :date_out, :date_in],
              unique: true, name: "idx_turkish_unique_search"
  end
end
