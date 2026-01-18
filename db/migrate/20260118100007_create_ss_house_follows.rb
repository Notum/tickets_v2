class CreateSsHouseFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :ss_house_follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ss_house_ad, null: false, foreign_key: true
      t.decimal :price_at_follow, precision: 12, scale: 2
      t.datetime :last_checked_at
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :ss_house_follows, [ :user_id, :ss_house_ad_id ], unique: true
    add_index :ss_house_follows, :status
  end
end
