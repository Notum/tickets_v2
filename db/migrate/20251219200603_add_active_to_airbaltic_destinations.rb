class AddActiveToAirbalticDestinations < ActiveRecord::Migration[8.0]
  def change
    add_column :airbaltic_destinations, :active, :boolean, default: true, null: false
  end
end
