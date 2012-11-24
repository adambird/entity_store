module EntityStore

  require 'hatchet'
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

    # Allows config to pass in a lambda or Proc to use as the type loader in place
    # of the default. 
    # Original use case was migration of entity classes to new module namespace when 
    # extracting to a shared library
    attr_accessor :type_loader
    
    def load_type(type_name)
      if type_loader
        type_loader.call(type_name)
      else
        type_name.split('::').inject(Object) {|obj, name| obj.const_get(name) }
      end
    end
  end


end