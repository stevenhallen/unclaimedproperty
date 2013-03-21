class AddReportedOnToProperties < ActiveRecord::Migration
  def change
    add_column :properties, :reported_on, :date
  end
end
