# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :notice do
    rec_id 1
    id_number 1
    property_table_html "MyText"
  end
end
