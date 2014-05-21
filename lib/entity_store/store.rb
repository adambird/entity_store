module EntityStore
  class Store
    include Logging

    def storage_client
      @_storage_client ||= EntityStore::Config.store
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
      unless entity.pending_events.empty?
        entity.version += 1
        if entity.id
          storage_client.save_entity(entity)
        else
          entity.id = storage_client.add_entity(entity)
        end
        add_events(entity)
        snapshot_entity(entity) if entity.version % Config.snapshot_threshold == 0

        # publish version increment signal event to the bus
        event_bus.publish(entity.type, entity.generate_version_incremented_event)
      end
      entity
    rescue => e
      log_error "Store#save error: #{e.inspect} - #{entity.inspect}", e
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
      options = {
        raise_exception: raise_exception
      }

      get_with_ids([id], options).first
    end

    # Public - get a series of entities
    #
    # ids           - Array of id strings
    # options       - Hash of options
    #               {
    #                 :raise_exceptions => Boolean
    #               }
    #
    # Returns and Array of entities
    def get_with_ids(ids, options={})

      entities = storage_client.get_entities(ids, options)

      criteria = entities.map { |e| { id: e.id, since_version: e.version } }

      storage_client.get_events_for_criteria(criteria).each_pair do |id, events|

        unless entity = entities.find { |e| e.id == id }
          raise "Unexpected entity with id=#{id} returned" if options[:raise_exception]
          next
        end

        events.each do |event|
          begin
            event.apply(entity)
            log_debug { "Applied #{event.inspect} to #{id}" }
          rescue => e
            log_error "Failed to apply #{event.class.name} #{event.attributes} to #{id} with #{e.inspect}", e
            raise if options[:raise_exception]
          end
          entity.version = event.entity_version
        end
      end

      entities
    end

    # Public : USE AT YOUR PERIL this clears the ENTIRE data store
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

    def event_bus
      @_event_bus ||= EventBus.new
    end

    # Public : returns an array representing a full audit trail for the entity.
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
            event.apply(entity)
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