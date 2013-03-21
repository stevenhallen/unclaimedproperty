class CreateProperties < ActiveRecord::Migration
  def change
    create_table :properties do |t|
      t.integer :id_number, :null => false
      t.text :raw_table
      t.datetime :downloaded_at

      t.timestamps
    end

    add_index :properties, :id_number, :unique => true
  end
end