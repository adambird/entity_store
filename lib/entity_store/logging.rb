module EntityStore
  module Logging

    def logger
      @_logger ||= EntityStore::Config.logger
    end

    def log_error(message, exception)
      logger.error message
      logger.error exception.backtrace
    end
  end
end