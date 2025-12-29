# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_29_102612) do
  create_table "airbaltic_destinations", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "city_name"
    t.string "country_name"
    t.string "country_code"
    t.datetime "announced_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.index ["code"], name: "index_airbaltic_destinations_on_code", unique: true
  end

  create_table "airbaltic_flight_searches", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "airbaltic_destination_id", null: false
    t.date "date_out", null: false
    t.date "date_in", null: false
    t.decimal "price_out", precision: 10, scale: 2
    t.decimal "price_in", precision: 10, scale: 2
    t.decimal "total_price", precision: 10, scale: 2
    t.boolean "is_direct_out"
    t.boolean "is_direct_in"
    t.string "status", default: "pending"
    t.text "api_response"
    t.datetime "priced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["airbaltic_destination_id"], name: "index_airbaltic_flight_searches_on_airbaltic_destination_id"
    t.index ["user_id", "airbaltic_destination_id", "date_out", "date_in"], name: "idx_airbaltic_unique_search", unique: true
    t.index ["user_id"], name: "index_airbaltic_flight_searches_on_user_id"
  end

  create_table "airbaltic_price_histories", force: :cascade do |t|
    t.integer "airbaltic_flight_search_id", null: false
    t.decimal "price_out", precision: 10, scale: 2
    t.decimal "price_in", precision: 10, scale: 2
    t.decimal "total_price", precision: 10, scale: 2
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["airbaltic_flight_search_id", "recorded_at"], name: "idx_airbaltic_price_history_search_recorded"
    t.index ["airbaltic_flight_search_id"], name: "index_airbaltic_price_histories_on_airbaltic_flight_search_id"
  end

  create_table "bode_destinations", force: :cascade do |t|
    t.string "name", null: false
    t.string "charter_path", null: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.index ["charter_path"], name: "index_bode_destinations_on_charter_path", unique: true
  end

  create_table "bode_flight_searches", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "bode_destination_id", null: false
    t.date "date_out", null: false
    t.date "date_in", null: false
    t.integer "nights"
    t.decimal "price", precision: 10, scale: 2
    t.string "airline"
    t.string "order_url"
    t.integer "free_seats"
    t.string "status", default: "pending"
    t.text "api_response"
    t.datetime "priced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bode_destination_id"], name: "index_bode_flight_searches_on_bode_destination_id"
    t.index ["user_id", "bode_destination_id", "date_out", "date_in"], name: "idx_bode_searches_unique", unique: true
    t.index ["user_id"], name: "index_bode_flight_searches_on_user_id"
  end

  create_table "bode_price_histories", force: :cascade do |t|
    t.integer "bode_flight_search_id", null: false
    t.decimal "price", precision: 10, scale: 2
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bode_flight_search_id", "recorded_at"], name: "idx_bode_price_history_search_recorded"
    t.index ["bode_flight_search_id"], name: "index_bode_price_histories_on_bode_flight_search_id"
  end

  create_table "norwegian_destinations", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "city_name"
    t.string "country_name"
    t.boolean "active", default: true, null: false
    t.datetime "announced_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_norwegian_destinations_on_code", unique: true
  end

  create_table "norwegian_flight_searches", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "norwegian_destination_id", null: false
    t.date "date_out", null: false
    t.date "date_in", null: false
    t.decimal "price_out", precision: 10, scale: 2
    t.decimal "price_in", precision: 10, scale: 2
    t.decimal "total_price", precision: 10, scale: 2
    t.boolean "is_direct_out"
    t.boolean "is_direct_in"
    t.string "status", default: "pending"
    t.text "api_response"
    t.datetime "priced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["norwegian_destination_id"], name: "index_norwegian_flight_searches_on_norwegian_destination_id"
    t.index ["user_id", "norwegian_destination_id", "date_out", "date_in"], name: "idx_norwegian_unique_search", unique: true
    t.index ["user_id"], name: "index_norwegian_flight_searches_on_user_id"
  end

  create_table "norwegian_price_histories", force: :cascade do |t|
    t.integer "norwegian_flight_search_id", null: false
    t.decimal "price_out", precision: 10, scale: 2
    t.decimal "price_in", precision: 10, scale: 2
    t.decimal "total_price", precision: 10, scale: 2
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["norwegian_flight_search_id", "recorded_at"], name: "idx_norwegian_price_history_search_recorded"
    t.index ["norwegian_flight_search_id"], name: "index_norwegian_price_histories_on_norwegian_flight_search_id"
  end

  create_table "ryanair_destinations", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "seo_name"
    t.string "city_name"
    t.string "city_code"
    t.string "country_name"
    t.string "country_code"
    t.string "currency_code"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "timezone"
    t.boolean "is_base", default: false
    t.boolean "seasonal", default: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "announced_at"
    t.index ["code"], name: "index_ryanair_destinations_on_code", unique: true
  end

  create_table "ryanair_flight_searches", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "ryanair_destination_id", null: false
    t.date "date_out", null: false
    t.date "date_in", null: false
    t.decimal "price_out", precision: 10, scale: 2
    t.decimal "price_in", precision: 10, scale: 2
    t.decimal "total_price", precision: 10, scale: 2
    t.string "status", default: "pending"
    t.text "api_response"
    t.datetime "priced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "departure_time_out"
    t.datetime "arrival_time_out"
    t.datetime "departure_time_in"
    t.datetime "arrival_time_in"
    t.index ["ryanair_destination_id"], name: "index_ryanair_flight_searches_on_ryanair_destination_id"
    t.index ["user_id"], name: "index_ryanair_flight_searches_on_user_id"
  end

  create_table "ryanair_price_histories", force: :cascade do |t|
    t.integer "ryanair_flight_search_id", null: false
    t.decimal "price_out", precision: 10, scale: 2
    t.decimal "price_in", precision: 10, scale: 2
    t.decimal "total_price", precision: 10, scale: 2
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ryanair_flight_search_id", "recorded_at"], name: "idx_price_history_search_recorded"
    t.index ["ryanair_flight_search_id"], name: "index_ryanair_price_histories_on_ryanair_flight_search_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price_notification_threshold", precision: 10, scale: 2, default: "5.0", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "airbaltic_flight_searches", "airbaltic_destinations"
  add_foreign_key "airbaltic_flight_searches", "users"
  add_foreign_key "airbaltic_price_histories", "airbaltic_flight_searches"
  add_foreign_key "bode_flight_searches", "bode_destinations"
  add_foreign_key "bode_flight_searches", "users"
  add_foreign_key "bode_price_histories", "bode_flight_searches"
  add_foreign_key "norwegian_flight_searches", "norwegian_destinations"
  add_foreign_key "norwegian_flight_searches", "users"
  add_foreign_key "norwegian_price_histories", "norwegian_flight_searches"
  add_foreign_key "ryanair_flight_searches", "ryanair_destinations"
  add_foreign_key "ryanair_flight_searches", "users"
  add_foreign_key "ryanair_price_histories", "ryanair_flight_searches"
end
