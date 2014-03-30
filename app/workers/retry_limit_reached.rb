# Sidekiq server middleware that calls an event method on a Worker when the retry
# limit for that Worker has been reached:
#
# https://github.com/mperham/sidekiq/issues/313
class RetryLimitReached
  def initialize(options=nil)
  end

  def call(worker, msg, queue)
    yield
  rescue => e
    # retry is either true, false, or numeric
    retry_limit = msg['retry']
    if retry_limit.is_a?(TrueClass)
      retry_limit = Sidekiq::Middleware::Server::RetryJobs::DEFAULT_MAX_RETRY_ATTEMPTS
    elsif retry_limit.is_a?(FalseClass)
      retry_limit = 0
    end

    if msg['retry_count'] && (msg['retry_count'] + 1 >= retry_limit)
      args = msg['args']

      arg = args.nil? || args.length == 0 ? nil : args[0]

      # Pass the first argument if one is available. In our case, the first argument
      # is usually the ID of a record that we want to load from the database.
      worker.on_failure(arg, e)
    end
    raise e
  end
end