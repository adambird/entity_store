module EntityStore
  class EventBus
    class << self
      def publish(entity_type, event)
        publish_externally entity_type, event

        EntityStore.logger.debug { "publishing #{event.inspect}" }

        subscribers_to(event.receiver_name).each do |s|
          begin
            s.new.send(event.receiver_name, event)
            EntityStore.logger.debug { "called #{s.name}##{event.receiver_name} with #{event.inspect}" }
          rescue => e
            EntityStore.logger.error { "#{e.message} when calling #{s.name}##{event.receiver_name} with #{event.inspect}" }
          end
        end
      end

      def subscribers_to(event_name)
        subscribers.select { |s| s.instance_methods.include?(event_name.to_sym) }
      end

      def subscribers
        EntityStore.event_subscribers
      end

      def publish_externally(entity_type, event)
        external_store.add_event(entity_type, event)
      end

      def external_store
        @_external_store ||= ExternalStore.new
      end
    end
  end
end