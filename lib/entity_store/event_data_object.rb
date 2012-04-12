module EntityStore
  class EventDataObject
    attr_reader :attrs
    
    def initialize(attrs={})
      @attrs = attrs
    end
    
    def id
      attrs['_id']
    end
    
    def entity_type
      attrs['_entity_type']
    end
    
    def type
      attrs['_type']
    end
    
    def [](key)
      attrs[key]
    end
  end
end