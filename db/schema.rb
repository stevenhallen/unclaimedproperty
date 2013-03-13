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

ActiveRecord::Schema.define(version: 20130313133457) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "properties", force: true do |t|
    t.integer  "id_number"
    t.text     "property_table_html"
    t.datetime "downloaded_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "notice_table_html"
    t.integer  "rec_id"
    t.decimal  "cash_report",         precision: 12, scale: 2
    t.date     "reported_on"
  end

  add_index "properties", ["id_number"], name: "index_properties_on_id_number", unique: true
  add_index "properties", ["rec_id"], name: "index_properties_on_rec_id", unique: true

end
