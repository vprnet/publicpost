uri = URI.parse(ENV["REDISTOGO_URL"])
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
REDIS_POOL  = ConnectionPool.new(:size => 8, :timeout => 60) { REDIS }