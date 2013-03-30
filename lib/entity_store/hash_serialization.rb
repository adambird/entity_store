module EntityStore
  module HashSerialization

    def initialize(attr={})
      attr.each { |item| send("#{item[0]}=", item[1]) if respond_to?("#{item[0]}=") }
    end

    # Public - generate attributes hash 
    # did use flatten but this came a-cropper when the attribute value was an array
    def attributes
      attrs = {}
      attribute_methods
        .collect { |m| [m, attribute_value(send(m))] }
        .each do |item| attrs[item[0]] = item[1] end
      attrs
    end

    def attribute_methods
      public_methods
        .select { |m| m =~ /\w\=$/ }
        .collect { |m| m.to_s.chop.to_sym }
        .select { |m| respond_to?(m) }
    end

    def attribute_value(value)
      if value.respond_to?(:attributes)
        value.attributes
      elsif value.is_a?(Hash)
        h = {}
        value.each_pair do |k,v| h[k] = attribute_value(v) end
        h
      elsif value.is_a?(Array)
        value.collect { |v| attribute_value(v) }
      else
        value
      end
    end

  end
end