class CreateFlydubaiFlightSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :flydubai_flight_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date_out, null: false
      t.date :date_in, null: false
      t.decimal :price_out, precision: 10, scale: 2
      t.decimal :price_in, precision: 10, scale: 2
      t.decimal :total_price, precision: 10, scale: 2
      t.boolean :is_direct_out
      t.boolean :is_direct_in
      t.string :status, default: "pending"
      t.text :api_response
      t.datetime :priced_at

      t.timestamps
    end

    add_index :flydubai_flight_searches, [:user_id, :date_out, :date_in],
              unique: true, name: "idx_flydubai_unique_search"
  end
end
