source 'https://rubygems.org'

# Heroku requirement
ruby '1.9.3'

gem 'activerecord-import', '0.2.9' # Required for said:populate
gem 'addressable', '2.3.2'
gem 'anemone', git: 'https://github.com/NearbyFYI/anemone' # Web crawler
gem 'best_in_place', '2.0.2'
gem 'bootstrap-sass', '2.2.2.0' # Nice UI in a box, components
gem 'bootstrap-will_paginate', '0.0.9'
gem 'calais', '0.0.13' # Open Calais for entity extraction
gem 'chronic', '0.9.0'
gem 'devise', '2.1.2'
gem 'faker', '1.0.1'
gem 'fog', '1.10.0' # API for Amazon S3 and other cloud services
gem 'haml-rails', '0.3.5'
gem 'httpclient', '2.4.0' # Used to download documents we find
gem 'jquery-rails', '2.0.2'
gem 'newrelic_rpm', '3.5.4.34'
gem 'newrelic-redis', '1.4.0'
gem 'paper_trail', '2.7.0' # Used to audit changes to models
gem 'paranoia', '1.2.0' # Used for "soft delete" of models
gem 'pg', '0.14.1'
gem 'rails', '3.2.11'
gem 'redcarpet'
gem 'roar', '0.11.4' # For hand crafting the API responses
gem 'roar-rails', '0.0.10' # For hand crafting the API responses
gem 'sidekiq', '2.6.1' # Messaging, workers
gem 'sidekiq-failures', '0.1.0'
# If you require 'sinatra' you get the DSL extended to Object
gem 'sinatra', '1.3.3', require: false # Used by Sidekiq UI
gem 'sprockets', '2.2.1'
gem 'tire', '0.5.2' # ElasticSearch DSL
gem 'unicorn', '4.5.0'
gem 'versionist', '0.3.1' # Used for versioning the API
gem 'will_paginate', '3.0.3'

# Gems used only for assets and not required in production environments by default.
group :assets do
  gem 'coffee-rails', '3.2.2'
  gem 'sass-rails', '3.2.5'
  gem 'uglifier', '1.3.0'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'foreman', '0.60.2'
  gem 'shotgun', '0.9'
end

group :test do
  gem 'capybara', '1.1.2'
  gem 'factory_girl_rails', '1.4.0'
  gem 'guard-rspec', '0.5.5'
  gem 'guard-spork', '0.3.2'
  gem 'rspec-rails', '2.8.1'
  gem 'spork', '0.9.0'

  # System-dependent gems
  gem 'rb-fsevent', '0.9.2', require: false
end
