module EntityStore
  class EventBus
    include Hatchet

    def publish(entity_type, event)
      publish_to_feed entity_type, event

      logger.debug { "publishing #{event.inspect}" }

      subscribers_to(event.receiver_name).each do |s|
        begin
          s.new.send(event.receiver_name, event)
          logger.debug { "called #{s.name}##{event.receiver_name} with #{event.inspect}" }
        rescue => e
          logger.error "#{e.message} when calling #{s.name}##{event.receiver_name} with #{event.inspect}", e
        end
      end
    end

    def subscribers_to(event_name)
      subscribers.select { |s| s.instance_methods.include?(event_name.to_sym) }
    end

    def subscribers
      EntityStore.event_subscribers
    end

    def publish_to_feed(entity_type, event)
      feed_store.add_event(entity_type, event) if feed_store
    end

    def feed_store
      EntityStore.feed_store
    end

    # Public - replay events of a given type to a given subscriber
    # 
    # since             - Time reference point
    # type              - String type name of event
    # subscriber        - Class of the subscriber to replay events to 
    # 
    # Returns nothing
    def replay(since, type, subscriber)
      max_items = 100
      event_data_objects = feed_store.get_events(since, type, max_items)

      while event_data_objects.count > 0 do 
        event_data_objects.each do |event_data_object|
          begin
            event = EntityStore.load_type(event_data_object.type).new(event_data_object.attrs)
            subscriber.new.send(event.receiver_name, event)
            logger.info { "replayed #{event.inspect} to #{subscriber.name}##{event.receiver_name}" }
          rescue => e
            logger.error "#{e.message} when replaying #{event_data_object.inspect} to #{subscriber}", e         
          end
        end
        event_data_objects = feed_store.get_events(event_data_objects.last.id, type, max_items)
      end
    end
  end
end