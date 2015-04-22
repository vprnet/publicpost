Sidekiq.configure_server do |config|
  config.failures_default_mode = :off

  config.server_middleware do |chain|
    chain.add RetryLimitReached
  end
end
