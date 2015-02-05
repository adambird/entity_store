module EntityStore
  module Entity
    attr_accessor :id

    def self.included(klass)
      klass.class_eval do
        include HashSerialization
        include Attributes

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

    def type
      self.class.name
    end

    def version
      @_version ||= 1
    end

    def version=(value)
      @_snapshot_version = value unless @_snapshot_version
      @_version = value
    end

    def snapshot_due?
      if version % Config.snapshot_threshold == 0
        true
      else
        @_snapshot_version and (version - @_snapshot_version) >= Config.snapshot_threshold
      end
    end

    def generate_version_incremented_event
      event_class= "#{self.class.name}VersionIncremented".split('::').inject(Object) {|obj, name| obj.const_get(name) }
      event_class.new(:entity_id => id, :version => version)
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
