module EntityStore
  module Logging

    [:debug, :info, :warn].each do |level|
      define_method("log_#{level}") do |message=nil, &block|
        Config.logger.send(level, message, &block) if Config.logger
      end
    end

    def log_error(message, exception)
      Config.logger.error(message, exception) if Config.logger
    end
  end
end
