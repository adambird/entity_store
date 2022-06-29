module EntityStore
  class Store
    include Logging

    def initialize(storage_client = nil, event_bus = nil)
      @_storage_client = storage_client if storage_client
      @_event_bus = event_bus if event_bus
    end

    def storage_client
      @_storage_client ||= EntityStore::Config.store
    end

    def event_bus
      @_event_bus ||= EventBus.new
    end

    def add(entity)
      entity.id = storage_client.add_entity(entity)
      add_events(entity)

      # publish version increment signal event to the bus
      event_bus.publish(entity.type, entity.generate_version_incremented_event)

      entity
    rescue => e
      logger.error { "Store#add error: #{e.inspect} - #{entity.inspect}" }
      raise e
    end

    def save(entity)
      # need to look at concurrency if we start storing version on client
      if entity.pending_events.empty?
        snapshot_entity(entity) if entity.snapshot_due?
      else
        entity.version += 1
        if entity.id
          storage_client.save_entity(entity)
        else
          entity.id = storage_client.add_entity(entity)
        end

        added_events = add_events(entity)

        if entity.snapshot_due? || added_events >= Config.snapshot_threshold
          snapshot_entity(entity)
        end

        # publish version increment signal event to the bus
        event_bus.publish(entity.type, entity.generate_version_incremented_event)
      end
      entity
    rescue => e
      log_error "Store#save error: #{e.inspect} - #{entity.inspect}", e
      raise e
    end

    # Upsert an entity where events have existed previously
    # for example when migrating data
    #
    # Please note this method requires that the events expose their id property
    # as a method named _id.
    #
    def upsert(entity)
      unless entity.pending_events.empty?
        entity.version = entity.pending_events.map(&:entity_version).max || 1

        if entity.id
          storage_client.save_entity(entity)
        else
          entity.id = storage_client.add_entity(entity)
        end

        upsert_events(entity)

        # publish version increment signal event to the bus
        event_bus.publish(entity.type, entity.generate_version_incremented_event)
      end
      entity
    rescue => e
      log_error "Store#upsert error: #{e.inspect} - #{entity.inspect}", e
      raise e
    end

    def snapshot_entity(entity)
      log_info { "Store#snapshot_entity : Snapshotting #{entity.id}"}
      storage_client.snapshot_entity(entity)
    end

    def remove_entity_snapshot(id)
      storage_client.remove_entity_snapshot(id)
    end

    def remove_snapshots type=nil
      storage_client.remove_snapshots type
    end

    def clear_entity_events(id, excluded_types = [])
      storage_client.clear_entity_events(id, excluded_types)
    end

    def add_events(entity)
      items = entity.pending_events.map do |event|
        event.entity_id = entity.id.to_s
        event.entity_version = entity.version
        event
      end
      storage_client.add_events(items)

      items.each { |e| event_bus.publish(entity.type, e) }

      entity.clear_pending_events
      items.count
    end

    def upsert_events(entity)
      items = entity.pending_events.map do |event|
        event.entity_id ||= entity.id.to_s
        event.entity_version ||= entity.version
        event
      end

      filtered_items = storage_client.upsert_events(items)

      filtered_items.each { |e| event_bus.publish(entity.type, e) }

      entity.clear_pending_events
    end

    def get!(id)
      get(id, true)
    end

    def get(id, raise_exception=false)
      options = {
        raise_exception: raise_exception
      }

      get_with_ids([id], options).first
    end

    # Public: get a series of entities
    #
    # ids           - Array of id strings
    # options       - Hash of options (default: {})
    #                 :raise_exception - Boolean (default true)
    #
    # Returns an Array of entities
    def get_with_ids(ids, options={})

      entities = Hash[ storage_client.get_entities(ids, options).map { |e| [ e.id, e] } ]

      if options.fetch(:raise_exception, true)
        ids.each do |id|
          raise NotFound.new(id) unless entities[id]
        end
      end

      criteria = entities.map do |id, entity|
        { id: id, since_version: entity.version }
      end

      events = storage_client.get_events(criteria)

      entities.each do |id, entity|

        next unless entity_events = events[id]

        entity_events.each do |event|
          begin
            entity.apply_event(event)
            log_debug { "Applied #{event.inspect} to #{id}" }
          rescue => e
            log_error "Failed to apply #{event.class.name} #{event.attributes} to #{id} with #{e.inspect}", e
            raise if options.fetch(:raise_exception, true)
          end
          entity.version = event.entity_version
        end

      end

      # ensure entities are returned in same order as requested
      ids.map { |id| entities[id] }

    end

    # Public: USE AT YOUR PERIL this clears the ENTIRE data store
    #
    # confirm     - Symbol that must equal :i_am_sure
    #
    # Returns nothing
    def clear_all(confirm)
      unless confirm == :i_am_sure
        raise "#clear_all call with :i_am_sure in order to do this"
      end
      storage_client.clear
      @_storage_client = nil
    end

    # Public: returns an array representing a full audit trail for the entity.
    # After each event is applied the state of the entity is rendered.
    # Optionally accepts a block which should return true or false to indicate
    # whether to render the line. The block yields entity, event, lines collection
    def get_audit(id, output=nil)
      lines = []

      if entity = storage_client.get_entity(id, true)

        lines << "---"
        lines << entity.inspect
        lines << "---"

        storage_client.get_events(id, entity.version).each do |event|

          begin
            entity.apply_event(event)
            entity.version = event.entity_version

            render = true

            if block_given?
              render = yield(entity, event, lines)
            end

            if render
              lines << event.inspect
              lines << entity.inspect

              lines << "---"
            end

          rescue => e
            lines << "ERROR #{e.class.name} #{e.message}"
          end
        end

      else
        lines << "No entity for #{id}"
      end

      if output
        output.write lines.join("\n")
      else
        lines
      end
    end

  end
end
