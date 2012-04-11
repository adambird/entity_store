module EntityStore
  require 'logger'
  require 'entity_store/entity'
  require 'entity_store/entity_value'
  require 'entity_store/event'
  require 'entity_store/store'
  require 'entity_store/mongo_entity_store'
  require 'entity_store/event_bus'
  require 'entity_store/not_found'

  class << self
    def setup
      yield self
    end
    
    def connection_profile
      @_connection_profile ||= "mongodb://localhost/entity_store_default"
    end

    def connection_profile=(value)
      @_connection_profile = value
    end

    def event_subscribers
      @_event_subscribers ||=[]
    end
    
    def log_level
      @_log_level ||= Logger::INFO
    end
    
    def log_level=(value)
      @_log_level = value
    end
    
    def logger
      unless @_logger
        @_logger = Logger.new(STDOUT)
        @_logger.progname = "Entity_Store"
      end
      @_logger.level = log_level
      @_logger
    end
  end


end