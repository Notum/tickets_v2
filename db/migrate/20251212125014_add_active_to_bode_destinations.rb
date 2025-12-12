class AddActiveToBodeDestinations < ActiveRecord::Migration[8.0]
  def change
    add_column :bode_destinations, :active, :boolean, default: true, null: false
  end
end
