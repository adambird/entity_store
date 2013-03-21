module EntityStore
  module Logging

    [:debug, :info, :warn].each do |level|
      define_method("log_#{level}") do |message=nil, &block|
        Config.logger.send(level, message || block) if Config.logger
      end
    end

    def log_error(message, exception)
      if Config.logger
        Config.logger.error message
        Config.logger.error exception.backtrace
      end
    end
  end
end