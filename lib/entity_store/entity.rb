module EntityStore
  module Entity
    attr_accessor :id
    attr_writer :version

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