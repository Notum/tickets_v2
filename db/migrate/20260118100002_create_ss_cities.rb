class CreateSsCities < ActiveRecord::Migration[8.0]
  def change
    create_table :ss_cities do |t|
      t.references :ss_region, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :name_lv, null: false
      t.string :name_ru
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :ss_cities, [ :ss_region_id, :slug ], unique: true
  end
end
