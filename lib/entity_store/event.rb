module EntityStore
  module Event
    attr_accessor :entity_id
    
    def initialize(attrs={})
      attrs.each_pair do |key, value|         
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end
    end
    
    def receiver_name
      elements = self.class.name.split('::')
      elements[elements.count - 1].
         gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
         gsub(/([a-z\d])([A-Z])/,'\1_\2').
         tr("-", "_").
         downcase
    end
    
    def attributes
      methods = self.public_methods.select {|m| m =~ /\w\=$/ && m != :connection_profile=}
      Hash[*methods.collect {|m| [m.to_s.chop.to_sym, self.send(m.to_s.chop)] }.flatten]
    end
  end
end