# uri = URI.parse(ENV["REDISTOGO_URL"])
uri = URI.parse("redis://root@23.253.237.4:6379")
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
REDIS_POOL  = ConnectionPool.new(:size => 8, :timeout => 60) { REDIS }
