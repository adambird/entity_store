module EntityStore
  require 'logger'
  require 'entity_store/cache'
  require 'entity_store/entity'
  require 'entity_store/entity_value'
  require 'entity_store/event'
  require 'entity_store/store'
  require 'entity_store/external_store'
  require 'entity_store/event_data_object'
  require 'entity_store/mongo_entity_store'
  require 'entity_store/event_bus'
  require 'entity_store/not_found'
  require 'entity_store/hash_serialization'
  require 'entity_store/attributes'

  class << self
    def setup
      yield self
    end
    
    # Public: cache to be used
    attr_accessor :cache

    def connection_profile
      @_connection_profile
    end

    def connection_profile=(value)
      @_connection_profile = value
    end

    def external_connection_profile
      @_external_connection_profile
    end

    def external_connection_profile=(value)
      @_external_connection_profile = value
    end
    
    def event_subscribers
      @_event_subscribers ||=[]
    end
    
    # Public - indicates the version increment that is used to 
    # decided whether a snapshot of an entity should be created when it's saved
    def snapshot_threshold
      @_snapshot_threshold ||= 10
    end

    def snapshot_threshold=(value)
      @_snapshot_threshold = value
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
        @_logger.level = log_level
      end
      @_logger
    end
    
    def logger=(value)
      @_logger = value
    end
  end


end