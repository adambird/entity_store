module EntityStore

  require 'entity_store/logging'
  require 'entity_store/config'
  require 'entity_store/entity'
  require 'entity_store/entity_value'
  require 'entity_store/event'
  require 'entity_store/store'
  require 'entity_store/event_data_object'
  require 'entity_store/event_bus'
  require 'entity_store/not_found'
  require 'entity_store/hash_serialization'
  require 'entity_store/attributes'

  if defined?(Mongo)
    require 'entity_store/mongo_entity_store'
    require 'entity_store/external_store'
  end

  class << self
    def setup
      yield EntityStore::Config.setup
    end
    
    def event_subscribers
      EntityStore::Config.event_subscribers
    end
  end

end