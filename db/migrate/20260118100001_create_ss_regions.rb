class CreateSsRegions < ActiveRecord::Migration[8.0]
  def change
    create_table :ss_regions do |t|
      t.string :slug, null: false
      t.string :name_lv, null: false
      t.string :name_ru
      t.string :parent_slug
      t.integer :position, default: 0
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :ss_regions, :slug, unique: true
    add_index :ss_regions, :parent_slug
  end
end
