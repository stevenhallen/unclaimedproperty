class AddMissingPropertyColumns < ActiveRecord::Migration
  def change
    add_column :properties, :owner_names, :string
    add_column :properties, :owner_address_lines, :string
    add_column :properties, :property_type, :string
    add_column :properties, :property_reported, :string
    add_column :properties, :reported_by, :string

    remove_column :properties, :notice_table_html
    remove_column :properties, :rec_id
    remove_column :properties, :reported_on
  end
end