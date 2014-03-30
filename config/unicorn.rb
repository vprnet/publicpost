require 'sidekiq'

if ENV["RAILS_ENV"] == "development"
  worker_processes 1
else
  worker_processes 2
end

timeout 30

after_fork do |server, worker|

  Sidekiq.configure_client do |config|
    config.redis = { :size => 1 }
  end
end