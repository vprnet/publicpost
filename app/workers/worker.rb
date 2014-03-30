# Base class for all task classes.
#
# Tasks can be run asynchronously, like so:
#
# MyTaskClass.perform_async(my_argument, "OnCompletion.execute(my_argument)")
#
# where the first parameter is a task-specific parameter and the the second
# parameter is an optional statement that should be executed upon completion
# of the task. One use of the second parameter is to asynchronously execute
# another task, thus "chaining" tasks together.
#
# Additionally, a task can be run synchronously like so:
#
# MyTaskClass.new.execute(my_argument)
#
# Subclasses must implement their logic in the run(arg) method. Additionally,
# if a task needs to perform any error handling, it can do so by extending
# the on_exception(arg, e, message) method. The implementation of this method
# merely raises the given exception.
class Worker
  include Sidekiq::Worker

  @@http_client = HTTPClient.new
  @@http_client.connect_timeout = Constants::DEFAULT_HTTP_TIMEOUT

  # Perform a task asynchronously.
  #
  # @param arg Argument used by the task
  # @param on_completion Optional statement to execute after completion of the task
  def perform(arg, on_completion)
    REDIS_POOL.with do |redis|
      execute(arg)
      eval on_completion unless on_completion.nil?
    end
  end

  # Perform a task synchronously.
  #
  # @param arg Argument used by the task
  def execute(arg)
    begin
      logger.info ">>> Executing #{self.class}(#{arg})"
      run(arg)
      on_success(arg)
      logger.info "<<< Completed #{self.class}(#{arg})"
    rescue => e
      logger.warn "!!! Failure #{self.class}(#{arg})"
      on_exception(arg, e, "!!! Caught exception while executing #{self.class}(#{arg}): #{e.message}")
    end
  end

  # Task implementation.
  #
  # @param arg Argument used by the task
  def run(arg)
  end

  # Handle an Exception thrown during task execution.
  #
  # @param arg Argument used by the task
  # @param e Exception that was thrown
  # @param message optional message about the Exception
  def on_exception(arg, e, message = nil)
    if message
      raise e, message, e.backtrace
    else
      raise e
    end
  end

  # Handle a failed execution of this task.
  #
  # @param arg Argument used by the task
  # @param e Exception that was thrown
  def on_failure(arg, e)
    logger.error "Fatal exception while executing #{self.class}(#{arg})"
  end

  # Handle a successful execution of this task.
  #
  # @param arg Argument used by the task
  def on_success(arg)
  end
end
