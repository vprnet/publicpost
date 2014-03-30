# TODO: should this be moved under the factories directory?

FactoryGirl.define do
  factory :municipality do
    name  "Somerville"
    state "MA"
    slug  "somerville-ma"

    code_fips "2501762535"
    code_gnis "62535"

    population 75754
    population_density 18403.9

    race_american_indian 0.002614
    race_asian 0.087203
    race_black 0.068128
    race_hispanic 0.105829
    race_multiple 0.035826
    race_non_hispanic  0.894171
    race_non_hispanic_white 0.691171
    race_other 0.066663
    race_pacific_islander 0.000409
    race_white 0.739156

    diversity 0.480113

    area_land 4.1
    area_water 0.1

    latitude 42.3905662
    longitude -71.1013245

    housing_units 33720
    housing_vacancies 1615
  end
end