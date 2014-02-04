module EntityStore
  module Entity
    attr_accessor :id

    def self.included(klass)
      klass.class_eval do
        include HashSerialization
        include Attributes
        extend ClassMethods

        version_incremented_event_class = "#{self.name}VersionIncremented".split('::').inject(Object) {|obj, name|
            obj.const_defined?(name) ? obj.const_get(name) : obj.const_set(name, Class.new)
          }

        version_incremented_event_class.class_eval %Q"
          include ::EntityStore::Event

          attr_accessor :version

          def apply(entity)
            # nothing to do as signal event
          end
        "
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
            if instance_variable_get("@#{name}_id") && @_related_entity_loader
              instance_variable_get("@_#{name}") || instance_variable_set("@_#{name}", @_related_entity_loader.get(instance_variable_get("@#{name}_id")))
            end
          }
        end

        define_method(:loaded_related_entities) {
          names.collect{ |name| instance_variable_get("@_#{name}") }.select{|entity| !entity.nil? }
        }
      end
    end

    def type
      self.class.name
    end

    def version
      @_version ||= 1
    end

    def version=(value)
      @_version = value
    end

    def generate_version_incremented_event
      event_class= "#{self.class.name}VersionIncremented".split('::').inject(Object) {|obj, name| obj.const_get(name) }
      event_class.new(:entity_id => id, :version => version)
    end

    # Holds a reference to the store used to load this entity so the same store
    # can be used for related entities
    def related_entity_loader=(value)
      @_related_entity_loader = value
    end

    def pending_events
      @pending_events ||= []
    end

    def clear_pending_events
      @pending_events = []
    end

    def record_event(event)
      apply_event(event)
      pending_events<<event
    end

    def apply_event(event)
      event.apply(self)
    end

    def inspect
      "<#{self.class.name} #{id} #{self.attributes.inspect}>"
    end
  end
end