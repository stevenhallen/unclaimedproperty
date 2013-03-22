class AddSearchablePropertyFields < ActiveRecord::Migration
  def change
    add_column :properties, :first_name, :string
    add_column :properties, :middle_name, :string
    add_column :properties, :last_name, :string
    add_column :properties, :street_address, :string
    add_column :properties, :city, :string
    add_column :properties, :state, :string
    add_column :properties, :postal_code, :string
  end
end