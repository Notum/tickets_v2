class AddRoomIdToBookingSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :booking_searches, :room_id, :string
    add_column :booking_searches, :block_id, :string

    # Update unique constraint to allow tracking multiple rooms at same hotel
    remove_index :booking_searches, name: "idx_booking_unique_search"
    add_index :booking_searches, [:user_id, :hotel_id, :room_id, :check_in, :check_out],
              unique: true, name: "idx_booking_unique_search"
  end
end
