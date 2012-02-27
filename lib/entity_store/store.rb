module EntityStore
  class Store
    def initialize(storage_client=nil)
      @storage_client = storage_client || MongoEntityStore.new
    end

    def add(entity)      
      entity.id = @storage_client.add_entity(entity)  
      add_events(entity)
      return entity
    end
    
    def save(entity)
      # need to look at concurrency if we start storing version on client
      entity.version += 1
      @storage_client.save_entity(entity)
      add_events(entity)
      return entity
    end
    
    def add_events(entity)
      entity.pending_events.each do |e|
        e.entity_id = entity.id.to_s
        @storage_client.add_event(e)
      end
      entity.pending_events.each {|e| EntityStore.event_bus.publish(e) }
    end

    def get!(id)
      get(id, true)
    end
    
    def get(id, raise_exception=false)
      if entity = @storage_client.get_entity(id, raise_exception)
        @storage_client.get_events(id).each { |e| e.apply(entity) }  
      end    
      return entity
    end
  end
end