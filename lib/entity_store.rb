module EntityStore
  require 'entity_store/entity'
  require 'entity_store/event'
  require 'entity_store/store'
  require 'entity_store/mongo_entity_store'
  require 'entity_store/event_bus'
  require 'entity_store/not_found'
  
  def self.connection_profile
    @@_connection_profile ||= "mongodb://localhost/entity_store_default"
  end
  
  def self.connection_profile=(value)
    @@_connection_profile = value
  end
  
  def self.event_subscribers
    @@_event_subscribers ||=[]
  end
  
  def self.setup
    yield self
  end
end