# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :question do
    survey_id 1
    content "MyString"
    answer 1
  end
end
