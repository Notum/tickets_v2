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

ActiveRecord::Schema[8.0].define(version: 2025_12_03_171142) do
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

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "ryanair_flight_searches", "ryanair_destinations"
  add_foreign_key "ryanair_flight_searches", "users"
end
