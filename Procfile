web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker: bundle exec sidekiq -v -c 3 -q high,4 -q medium,3 -q low,2 -q default,1