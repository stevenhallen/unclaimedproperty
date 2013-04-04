class SetPropertiesIdNumberToNull < ActiveRecord::Migration
  def change
    change_column :properties, :id_number, :integer, :null => false
  end
end
