require 'spec_helper'

describe 'Static pages' do

  describe 'About page' do

    it "should have the content 'About Us'" do
      visit('/about')
      page.should(have_content('About Us'))
    end
  end

  describe 'Home page' do

    it "should have the content 'He Said, She Said'" do
      visit('/')
      page.should(have_content('He Said, She Said'))
    end
  end

  describe 'Contact page' do

    it "should have the content 'Contact'" do
      visit('/contact')
      page.should(have_content('Contact'))
    end
  end

  describe 'Municipalities page' do

    it "should have the content 'Cities & Towns'" do
      visit('/municipalities')
      page.should(have_content('Cities & Towns'))
    end
  end
end