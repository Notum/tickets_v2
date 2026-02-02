class AddBodeFlightIdToBodeFlightSearches < ActiveRecord::Migration[8.0]
  def change
    add_reference :bode_flight_searches, :bode_flight, null: true, foreign_key: true
  end
end
