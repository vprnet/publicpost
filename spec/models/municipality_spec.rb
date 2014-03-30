require 'spec_helper'

describe 'Municipality' do
  before { @municipality = FactoryGirl.create(:municipality) }
  subject { @municipality }

  it { should respond_to(:name) }
  it { should respond_to(:state) }
  it { should respond_to(:slug) }

  it { should respond_to(:code_fips) }
  it { should respond_to(:code_gnis) }

  it { should respond_to(:population) }
  it { should respond_to(:population_density) }

  it { should respond_to(:race_american_indian) }
  it { should respond_to(:race_asian) }
  it { should respond_to(:race_black) }
  it { should respond_to(:race_hispanic) }
  it { should respond_to(:race_multiple) }
  it { should respond_to(:race_non_hispanic) }
  it { should respond_to(:race_non_hispanic_white) }
  it { should respond_to(:race_other) }
  it { should respond_to(:race_pacific_islander) }
  it { should respond_to(:race_white) }

  it { should respond_to(:diversity) }

  it { should respond_to(:area_land) }
  it { should respond_to(:area_water) }

  it { should respond_to(:latitude) }
  it { should respond_to(:longitude) }

  it { should respond_to(:housing_units) }
  it { should respond_to(:housing_vacancies) }

  it { should respond_to(:website) }

  it { should be_valid }

  describe 'when name is not present' do
    before { @municipality.name = ' ' }
    it { should_not be_valid }
  end

  describe 'when state is not present' do
    before { @municipality.state = ' ' }
    it { should_not be_valid }
  end

  describe 'when slug is not present' do
    before { @municipality.slug = ' ' }
    it { should_not be_valid }
  end

  describe 'when population is invalid' do
    before { @municipality.population = -1 }
    it { should_not be_valid }
  end

  describe 'when population_density is invalid' do
    before { @municipality.population_density = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_american_indian is invalid' do
    before { @municipality.race_american_indian = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_asian is invalid' do
    before { @municipality.race_asian = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_black is invalid' do
    before { @municipality.race_black = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_hispanic is invalid' do
    before { @municipality.race_hispanic = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_multiple is invalid' do
    before { @municipality.race_multiple = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_non_hispanic is invalid' do
    before { @municipality.race_non_hispanic = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_non_hispanic_white is invalid' do
    before { @municipality.race_non_hispanic_white = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_other is invalid' do
    before { @municipality.race_other = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_pacific_islander is invalid' do
    before { @municipality.race_pacific_islander = -1.0 }
    it { should_not be_valid }
  end

  describe 'when race_white is invalid' do
    before { @municipality.race_white = -1.0 }
    it { should_not be_valid }
  end

  describe 'when diversity is invalid' do
    before { @municipality.diversity = -1.0 }
    it { should_not be_valid }
  end

  describe 'when area_land is invalid' do
    before { @municipality.area_land = -1 }
    it { should_not be_valid }
  end

  describe 'when area_water is invalid' do
    before { @municipality.area_water = -1 }
    it { should_not be_valid }
  end

  describe 'when latitude is not present' do
    before { @municipality.latitude = nil }
    it { should_not be_valid }
  end

  describe 'when longitude is not present' do
    before { @municipality.longitude = nil }
    it { should_not be_valid }
  end

  describe 'when housing_units is invalid' do
    before { @municipality.housing_units = -1 }
    it { should_not be_valid }
  end

  describe 'when housing_vacancies is invalid' do
    before { @municipality.housing_vacancies = -1 }
    it { should_not be_valid }
  end
end
