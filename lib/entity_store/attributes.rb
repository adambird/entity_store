module EntityStore
  module Attributes
    def self.included klass
      klass.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods
      def entity_value_attribute name, klass
        define_method(name) { instance_variable_get("@#{name}") }
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", self.class._eval_entity_value_setter(value, klass))
        end
      end

      def _eval_entity_value_setter value, klass
        case value
        when Array 
          klass.new(Hash[*value.flatten])
        when Hash
          klass.new(value)
        else
          value
        end
      end

      def entity_value_array_attribute name, klass
        define_method(name) {
          instance_variable_get("@_#{name}") || instance_variable_set("@_#{name}", [])
        }

        define_method("#{name}=") do |value|
          value.each do |item|
            case item
            when Hash
              send(name) << klass.new(item)
            when klass
              send(name) << item
            else
              raise ArgumentError.new("#{item.class.name} not supported. Expecting #{klass.name}")
            end
          end
        end
      end
    end
  end
end
