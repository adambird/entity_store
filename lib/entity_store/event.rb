module EntityStore
  module Event
    attr_accessor :entity_id
    
    def initialize(attrs={})
      attrs.each_pair do |key, value|         
        send("#{key}=", value) if respond_to?("#{key}=")
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
      Hash[*public_methods.select {|m| m =~ /\w\=$/}.collect do |m|
        attribute_name = m.to_s.chop.to_sym
        [attribute_name, send(attribute_name).respond_to?(:attributes) ? send(attribute_name).attributes : send(attribute_name)]
      end.flatten]
    end
    
    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
      end
    end
    
    module ClassMethods
      def time_attribute(*names)
        class_eval do
          names.each do |name|
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
      
      def entity_value_attribute(name, klass)
        define_method(name) { instance_variable_get("@#{name}") }
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", value.is_a?(Hash) ? klass.new(value) : value)
        end
      end
    end
  end
end