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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140611145802) do

  create_table "api_keys", :force => true do |t|
    t.string   "access_token"
    t.string   "name"
    t.string   "email"
    t.datetime "expires_at"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  create_table "documents", :force => true do |t|
    t.string   "guid"
    t.string   "content_type"
    t.string   "content_url",        :limit => 510
    t.string   "hsss_persisted_url"
    t.date     "last_modified"
    t.text     "extracted_text"
    t.text     "analyzed_text"
    t.string   "title"
    t.string   "classification"
    t.string   "legislative_body"
    t.string   "status"
    t.date     "likely_date"
    t.string   "state"
    t.text     "state_details"
    t.integer  "municipality_id"
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
    t.datetime "deleted_at"
    t.boolean  "useful"
    t.text     "people"
    t.text     "locations"
    t.text     "organizations"
    t.text     "terms"
    t.string   "persisted_url"
  end

  add_index "documents", ["classification"], :name => "index_documents_on_classification"
  add_index "documents", ["content_type"], :name => "index_documents_on_content_type"
  add_index "documents", ["guid"], :name => "index_documents_on_guid"
  add_index "documents", ["legislative_body"], :name => "index_documents_on_legislative_body"
  add_index "documents", ["likely_date"], :name => "index_documents_on_likely_date"
  add_index "documents", ["municipality_id", "classification"], :name => "index_documents_on_municipality_id_and_classification"
  add_index "documents", ["status"], :name => "index_documents_on_status"

  create_table "entities", :force => true do |t|
    t.string   "guid"
    t.string   "kind"
    t.string   "name"
    t.string   "commonname"
    t.string   "reference_type"
    t.string   "organization_kind"
    t.string   "person_kind"
    t.string   "nationality"
    t.integer  "document_id"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
  end

  add_index "entities", ["document_id"], :name => "index_entities_on_document_id"
  add_index "entities", ["kind"], :name => "index_entities_on_kind"

  create_table "instances", :force => true do |t|
    t.text     "detection"
    t.text     "prefix"
    t.text     "exact"
    t.text     "suffix"
    t.integer  "offset"
    t.integer  "length"
    t.float    "relevance"
    t.integer  "entity_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "municipalities", :force => true do |t|
    t.string   "name"
    t.string   "state"
    t.string   "slug"
    t.string   "website"
    t.boolean  "website_accept_cookies"
    t.string   "website_linkable_domains"
    t.string   "website_skip_links"
    t.string   "website_strip_params"
    t.string   "code_fips"
    t.string   "code_gnis"
    t.integer  "population"
    t.float    "population_density"
    t.float    "race_american_indian"
    t.float    "race_asian"
    t.float    "race_black"
    t.float    "race_hispanic"
    t.float    "race_multiple"
    t.float    "race_non_hispanic"
    t.float    "race_non_hispanic_white"
    t.float    "race_other"
    t.float    "race_pacific_islander"
    t.float    "race_white"
    t.float    "diversity"
    t.float    "area_land"
    t.float    "area_water"
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "housing_units"
    t.integer  "housing_vacancies"
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
    t.datetime "last_crawl_date"
    t.string   "display_name"
  end

  add_index "municipalities", ["latitude", "longitude"], :name => "index_municipalities_on_latitude_and_longitude"
  add_index "municipalities", ["name"], :name => "index_municipalities_on_name"
  add_index "municipalities", ["slug"], :name => "index_municipalities_on_slug"
  add_index "municipalities", ["state"], :name => "index_municipalities_on_state"
  add_index "municipalities", ["website"], :name => "index_municipalities_on_website"

  create_table "search_alerts", :force => true do |t|
    t.string   "querystring"
    t.string   "recipient_email"
    t.string   "recipient_name"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
    t.integer  "user_id"
  end

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "",    :null => false
    t.string   "encrypted_password",     :default => "",    :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
    t.boolean  "admin",                  :default => false
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

  create_table "versions", :force => true do |t|
    t.string   "item_type",      :null => false
    t.integer  "item_id",        :null => false
    t.string   "event",          :null => false
    t.string   "whodunnit"
    t.text     "object"
    t.string   "ip"
    t.string   "user_agent"
    t.datetime "created_at"
    t.text     "object_changes"
  end

  add_index "versions", ["item_type", "item_id"], :name => "index_versions_on_item_type_and_item_id"

end
