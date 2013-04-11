FactoryGirl.define do
  factory :property do
    id_number 1
    property_table_html { File.open('spec/factories/raw_table.html').read }
  end
end