module EntityStore
  module Entity
    attr_accessor :id
    
    # Holds a reference to the store used to load this entity so the same store
    # can be used for related entities
    attr_accessor :related_entity_loader

    attr_writer :version

    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods

      def related_entities(*names)
        names.each do |name|
          # attr accessor for the id
          define_method("#{name}_id") { instance_variable_get("@#{name}_id")}
          define_method("#{name}_id=") do |value| instance_variable_set("@#{name}_id", value) end

          # lazy loader for related entity
          define_method(name) {
            if instance_variable_get("@#{name}_id") && related_entity_loader
              instance_variable_get("@_#{name}") || instance_variable_set("@_#{name}", related_entity_loader.get(instance_variable_get("@#{name}_id")))
            end
          }
        end

        define_method(:loaded_related_entities) {
          names.collect{ |name| instance_variable_get("@_#{name}") }.select{|entity| !entity.nil? }
        }
      end

    end

    def initialize(attr={})
      attr.each_pair { |k,v| self.send("#{k}=", v) }
    end
    
    def type
      self.class.name
    end
  
    def version
      @version ||= 1
    end
  
    def pending_events
      @pending_events ||= []
    end
  
    def record_event(event)
      apply_event(event)
      pending_events<<event
    end
  
    def apply_event(event)
      event.apply(self)
    end
  end
end