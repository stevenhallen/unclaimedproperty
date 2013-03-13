class AddRecIdToProperties < ActiveRecord::Migration
  def change
    add_column :properties, :rec_id, :integer

    add_index :properties, :rec_id, :unique => true

    change_column :properties, :id_number, :integer, :null => true
  end
end