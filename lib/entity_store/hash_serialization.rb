module EntityStore
  module HashSerialization

    def initialize(attr={})
      attr.each_pair { |k,v| send("#{k}=", v) if respond_to?("#{k}=") }
    end

    # Public - generate attributes hash 
    # did use flatten but this came a-cropper when the attribute value was an array
    def attributes
      attrs = {}
      public_methods
        .select { |m| m =~ /\w\=$/ }
        .select { |m| respond_to?(m.to_s.chop) }
        .collect { |m| m.to_s.chop.to_sym }
        .collect { |m| [m, attribute_value(send(m))] }
        .each do |item| attrs[item[0]] = item[1] end
      attrs
    end

    def attribute_value(value)
      if value.respond_to?(:attributes)
        value.attributes
      elsif value.respond_to?(:each)
        value.collect { |v| attribute_value(v) }
      else
        value
      end
    end

  end
end