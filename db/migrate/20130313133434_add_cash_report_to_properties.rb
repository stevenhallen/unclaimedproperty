class AddCashReportToProperties < ActiveRecord::Migration
  def change
    add_column :properties, :cash_report, :decimal, :precision => 12, :scale => 2
  end
end
