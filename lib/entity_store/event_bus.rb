module EntityStore
  class EventBus
    include Logging

    ALL_METHOD = :all_events

    def publish(entity_type, event)
      publish_to_feed entity_type, event

      subscribers_to(event.receiver_name).each do |s| send_to_subscriber s, event.receiver_name, event end
      subscribers_to_all.each do |s| send_to_subscriber s, ALL_METHOD, event end
    end

    def send_to_subscriber subscriber, receiver_name, event
      subscriber.new.send(receiver_name, event)
      log_debug { "called #{subscriber.name}##{receiver_name} with #{event.inspect}" }
    rescue => e
      log_error "#{subscriber.name}##{receiver_name} failed - #{e.class} - #{e.message} - entity=#{event.entity_id}, version=#{event.entity_version}", e
    end

    def subscribers_to(event_name)
      subscribers.select { |s| s.instance_methods.include?(event_name.to_sym) }
    end

    def subscribers_to_all
      subscribers.select { |s| s.instance_methods.include?(ALL_METHOD) }
    end

    def subscribers
      EntityStore::Config.event_subscribers.map do |subscriber|
        case subscriber
        when String
          Utils.get_type_constant(subscriber)
        else
          subscriber
        end
      end
    end

    def publish_to_feed(entity_type, event)
      feed_store.add_event(entity_type, event) if feed_store
    end

    def feed_store
      EntityStore::Config.feed_store
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
            event = EntityStore::Config.load_type(event_data_object.type).new(event_data_object.attrs)
            subscriber.new.send(event.receiver_name, event)
            log_debug { "replayed #{event.inspect} to #{subscriber.name}##{event.receiver_name}" }
          rescue => e
            log_error "#{subscriber.name}##{event.receiver_name} replay failed - #{e.class} - #{e.message} - entity=#{event.entity_id}, version=#{event.entity_version}", e
          end
        end
        event_data_objects = feed_store.get_events(event_data_objects.last.id, type, max_items)
      end
    end
  end
end
