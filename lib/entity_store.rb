module EntityStore
  
  def event_bus
    @@_event_bus
  end
  
  def event_bus=(value)
    @@_event_bus = value
  end
  
  def connection_profile
    @@_connection_profile
  end
  
  def connection_profile=(value)
    @@_connection_profile = value
  end
  
  def self.setup
    yield self
  end
end