module EntityStore
  class EventBus
    class << self
      def publish(event)
        publish_externally event
        
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
        subscribers.select { |s| s.instance_method_names.include?(event_name) }
      end
            
      def subscribers
        EntityStore.event_subscribers
      end
      
      def publish_externally(event)
        
      end
    end
  end
end