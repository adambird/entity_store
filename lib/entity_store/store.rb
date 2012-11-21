module EntityStore
  class Store
    include Hatchet

    def storage_client
      @_storage_client ||= MongoEntityStore.new
    end

    def add(entity)
      entity.id = storage_client.add_entity(entity)
      add_events(entity)
      entity
    rescue => e
      logger.error { "Store#add error: #{e.inspect} - #{entity.inspect}" }
      raise e
    end

    def save(entity)
      do_save entity
      entity.loaded_related_entities.each do |e| do_save e end if entity.respond_to?(:loaded_related_entities)
      entity
    end

    def do_save(entity)
      # need to look at concurrency if we start storing version on client
      unless entity.pending_events.empty?
        entity.version += 1
        if entity.id
          storage_client.save_entity(entity)
        else
          entity.id = storage_client.add_entity(entity)
        end
        add_events(entity)
        snapshot_entity(entity) if entity.version % EntityStore.snapshot_threshold == 0
      end
      entity
    rescue => e
      logger.error { "Store#do_save error: #{e.inspect} - #{entity.inspect}" }
      raise e
    end

    def snapshot_entity(entity)
      logger.info { "Store#snapshot_entity : Snapshotting #{entity.id}"}
      storage_client.snapshot_entity(entity)
    end

    def remove_entity_snapshot(id)
      storage_client.remove_entity_snapshot(id)
    end

    def add_events(entity)
      entity.pending_events.each do |e|
        e.entity_id = entity.id.to_s
        e.entity_version = entity.version
        storage_client.add_event(e)
      end
      entity.pending_events.each {|e| event_bus.publish(entity.type, e) }
      entity.clear_pending_events
    end

    def get!(id)
      get(id, true)
    end

    def get(id, raise_exception=false)
      if entity = storage_client.get_entity(id, raise_exception)
        # assign this entity loader to allow lazy loading of related entities
        entity.related_entity_loader = self
      end
      entity
    end

    # Public : USE AT YOUR PERIL this clears the ENTIRE data store
    #
    # Returns nothing
    def clear_all
      storage_client.entities.drop
      storage_client.events.drop
      @_storage_client = nil
    end

    def event_bus
      @_event_bus ||= EventBus.new
    end
  end
end