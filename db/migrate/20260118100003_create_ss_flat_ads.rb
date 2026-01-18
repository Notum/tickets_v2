class CreateSsFlatAds < ActiveRecord::Migration[8.0]
  def change
    create_table :ss_flat_ads do |t|
      t.string :external_id, null: false
      t.string :content_hash, null: false
      t.references :ss_region, null: false, foreign_key: true
      t.references :ss_city, foreign_key: true
      t.string :street
      t.integer :rooms
      t.decimal :area, precision: 10, scale: 2
      t.integer :floor_current
      t.integer :floor_total
      t.string :building_series
      t.string :house_type
      t.string :deal_type, null: false, default: "sell"
      t.decimal :price, precision: 12, scale: 2
      t.decimal :price_per_m2, precision: 10, scale: 2
      t.string :title
      t.text :description
      t.string :thumbnail_url
      t.json :image_urls
      t.string :original_url, null: false
      t.datetime :posted_at
      t.datetime :last_seen_at
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :ss_flat_ads, :external_id, unique: true
    add_index :ss_flat_ads, :content_hash
    add_index :ss_flat_ads, :deal_type
    add_index :ss_flat_ads, :active
    add_index :ss_flat_ads, [ :ss_region_id, :rooms ]
    add_index :ss_flat_ads, :price
  end
end
