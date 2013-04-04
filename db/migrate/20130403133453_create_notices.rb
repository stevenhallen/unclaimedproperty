class CreateNotices < ActiveRecord::Migration
  def change
    create_table :notices do |t|
      t.integer  :rec_id, :null => false
      t.integer  :id_number
      t.text     :notice_table_html
      t.datetime :downloaded_at
      t.datetime :reported_on
      t.decimal  :cash_report
      t.string   :owner_names
      t.string   :owner_address_lines
      t.string   :property_type
      t.string   :property_reported
      t.string   :reported_by
      t.string   :first_name
      t.string   :middle_name
      t.string   :last_name
      t.string   :street_address
      t.string   :city
      t.string   :state
      t.string   :postal_code

      t.timestamps
    end
  end
end
