class AddNoticeTableToProperties < ActiveRecord::Migration
  def change
    add_column :properties, :notice_table_html, :text

    rename_column :properties, :raw_table, :property_table_html
  end
end
