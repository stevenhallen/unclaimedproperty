# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :property do
    url "MyString"
    record_id 1
    id_number 1
    raw_table "MyText"
    downloaded_at "2013-03-09 09:23:20"
  end
end
