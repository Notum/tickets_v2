class AddPriceNotificationThresholdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :price_notification_threshold, :decimal, precision: 10, scale: 2, default: 5.0, null: false
  end
end
