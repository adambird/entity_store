module EntityStore

  require 'hatchet'
  require 'entity_store/entity'
  require 'entity_store/entity_value'
  require 'entity_store/event'
  require 'entity_store/store'
  require 'entity_store/external_store'
  require 'entity_store/event_data_object'
  require 'entity_store/mongo_entity_store' if 
  require 'entity_store/event_bus'
  require 'entity_store/not_found'
  require 'entity_store/hash_serialization'
  require 'entity_store/attributes'

  class << self
    attr_accessor :store, :feed_store

    def setup
      yield self

      raise StandardError.new("EntityStore.store not assigned") unless store
      store.open 
      feed_store.open if feed_store
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
      if EntityStore.type_loader
        EntityStore.type_loader.call(type_name)
      else
        type_name.split('::').inject(Object) {|obj, name| obj.const_get(name) }
      end
    end

    def connect_timeout
      (ENV['ENTITY_STORE_CONNECT_TIMEOUT'] || '2').to_i
    end
  end

end