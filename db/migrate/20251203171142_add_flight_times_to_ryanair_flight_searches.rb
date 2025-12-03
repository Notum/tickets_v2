class AddFlightTimesToRyanairFlightSearches < ActiveRecord::Migration[8.0]
  def change
    # Remove old simple time columns
    remove_column :ryanair_flight_searches, :time_out, :string
    remove_column :ryanair_flight_searches, :time_in, :string

    # Add detailed flight time columns
    add_column :ryanair_flight_searches, :departure_time_out, :datetime
    add_column :ryanair_flight_searches, :arrival_time_out, :datetime
    add_column :ryanair_flight_searches, :departure_time_in, :datetime
    add_column :ryanair_flight_searches, :arrival_time_in, :datetime
  end
end
