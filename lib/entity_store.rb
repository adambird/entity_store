module EntityStore
  require_relative 'entity_store/logging'
  require_relative 'entity_store/config'
  require_relative 'entity_store/time_factory'
  require_relative 'entity_store/event'
  require_relative 'entity_store/attributes'
  require_relative 'entity_store/hash_serialization'
  require_relative 'entity_store/entity'
  require_relative 'entity_store/entity_value'
  require_relative 'entity_store/store'
  require_relative 'entity_store/event_data_object'
  require_relative 'entity_store/event_bus'
  require_relative 'entity_store/not_found'

  class << self
    def setup
      yield EntityStore::Config.setup
    end

    def event_subscribers
      EntityStore::Config.event_subscribers
    end
  end

end
