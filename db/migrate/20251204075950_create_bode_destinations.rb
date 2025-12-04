class CreateBodeDestinations < ActiveRecord::Migration[8.0]
  def change
    create_table :bode_destinations do |t|
      t.string :name, null: false
      t.string :charter_path, null: false
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :bode_destinations, :charter_path, unique: true
  end
end
