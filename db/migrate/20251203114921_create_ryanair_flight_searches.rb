class CreateRyanairFlightSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :ryanair_flight_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ryanair_destination, null: false, foreign_key: true
      t.date :date_out, null: false
      t.date :date_in, null: false
      t.decimal :price_out, precision: 10, scale: 2
      t.decimal :price_in, precision: 10, scale: 2
      t.decimal :total_price, precision: 10, scale: 2
      t.string :status, default: "pending"
      t.text :api_response
      t.datetime :priced_at

      t.timestamps
    end
  end
end
