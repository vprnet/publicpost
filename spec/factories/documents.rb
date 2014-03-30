# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :document do |f|
    f.content_url "http://www.governmentdocument.com/doc"
    f.extracted_text "Foo bar text goes here"
  end
end