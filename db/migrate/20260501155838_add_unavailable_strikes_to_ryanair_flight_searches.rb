class AddUnavailableStrikesToRyanairFlightSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :ryanair_flight_searches, :unavailable_strikes, :integer, default: 0, null: false
  end
end
