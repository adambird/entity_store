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
      methods = self.public_methods.select {|m| m =~ /\w\=$/}
      Hash[*methods.collect {|m| [m.to_s.chop.to_sym, self.send(m.to_s.chop)] }.flatten]
    end
    
    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
      end
    end
    
    module ClassMethods
      def time_attribute(name)
        class_eval do
          define_method "#{name}=" do |value|
            require 'time'
            instance_variable_set("@#{name}", value.kind_of?(String) ? Time.parse(value) : value)
          end
          define_method name do
            instance_variable_get "@#{name}"
          end
        end
      end
      
    end
  end
end