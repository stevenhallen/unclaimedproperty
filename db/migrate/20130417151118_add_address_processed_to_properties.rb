class AddAddressProcessedToProperties < ActiveRecord::Migration
  def change
    add_column :properties, :address_processed, :boolean, :default => false
  end
end