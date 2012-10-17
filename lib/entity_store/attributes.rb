module EntityStore
  module Attributes
    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods
      def entity_value_attribute(name, klass)
        define_method(name) { instance_variable_get("@#{name}") }
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", self.class._eval_entity_value_setter(value, klass))
        end
      end

      def _eval_entity_value_setter(value, klass)
        case value
        when Array 
          klass.new(Hash[*value.flatten])
        when Hash
          klass.new(value)
        else
          value
        end
      end

    end
  end
end
