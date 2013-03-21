FactoryGirl.define do
  factory :property do
    id_number 1
    raw_table { File.open('spec/factories/raw_table.html').read }
  end
end