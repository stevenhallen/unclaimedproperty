# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20130417151118) do

  create_table "delayed_jobs", force: true do |t|
    t.integer  "priority",   default: 0
    t.integer  "attempts",   default: 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority"

  create_table "notices", force: true do |t|
    t.integer  "rec_id",              null: false
    t.integer  "id_number"
    t.text     "notice_table_html"
    t.datetime "downloaded_at"
    t.datetime "reported_on"
    t.decimal  "cash_report"
    t.string   "owner_names"
    t.string   "owner_address_lines"
    t.string   "property_type"
    t.string   "property_reported"
    t.string   "reported_by"
    t.string   "first_name"
    t.string   "middle_name"
    t.string   "last_name"
    t.string   "street_address"
    t.string   "city"
    t.string   "state"
    t.string   "postal_code"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "notifications", force: true do |t|
    t.string   "first_name"
    t.string   "middle_name"
    t.string   "last_name"
    t.string   "state"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "properties", force: true do |t|
    t.integer  "id_number",                                                    null: false
    t.text     "property_table_html"
    t.datetime "downloaded_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "cash_report",         precision: 12, scale: 2
    t.string   "owner_names"
    t.string   "owner_address_lines"
    t.string   "property_type"
    t.string   "property_reported"
    t.string   "reported_by"
    t.string   "first_name"
    t.string   "middle_name"
    t.string   "last_name"
    t.string   "street_address"
    t.string   "city"
    t.string   "state"
    t.string   "postal_code"
    t.boolean  "address_processed",                            default: false
  end

  add_index "properties", ["id_number"], name: "index_properties_on_id_number", unique: true

end
