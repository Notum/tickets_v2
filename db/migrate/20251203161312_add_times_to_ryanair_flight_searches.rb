class AddTimesToRyanairFlightSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :ryanair_flight_searches, :time_out, :string
    add_column :ryanair_flight_searches, :time_in, :string
  end
end
