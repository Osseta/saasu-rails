module Saasi
  class StringArrayType < ActiveModel::Type::Value
    def cast(value)
      return if value.nil? # nil stays nil so to_wire omits the field; Array(nil) would emit []
      Array(value).map(&:to_s)
    end
  end
  ActiveModel::Type.register(:string_array, StringArrayType)

  class Base
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_reader :extra

    def initialize(attributes = {})
      @extra = {}
      super
    end

    class << self
      def wraps(klass = nil)
        @legacy_class = klass if klass
        @legacy_class
      end

      def wire_map
        @wire_map ||= superclass.respond_to?(:wire_map) ? superclass.wire_map.dup : {}
      end

      def attribute(name, type = ActiveModel::Type::Value.new, wire_key: nil, **options)
        wire_map[wire_key || name.to_s.camelize] = name
        super(name, type, **options)
      end

      def from_wire(hash)
        new.assign_wire(hash)
      end
    end

    def assign_wire(hash)
      hash.each do |key, value|
        key = key.to_s
        if (attr_name = self.class.wire_map[key])
          public_send("#{attr_name}=", value)
        elsif self.class.attribute_types.key?(key)
          # snake_case attribute name (user-supplied hash rather than API wire hash)
          public_send("#{key}=", value)
        else
          extra[key] = value
        end
      end
      self
    end

    def to_wire
      # declared keys always win over stray extra entries, even when the declared value is nil
      wire = extra.reject { |key, _| self.class.wire_map.key?(key) }
      self.class.wire_map.each do |key, attr_name|
        value = public_send(attr_name)
        wire[key] = serialize_wire_value(value) unless value.nil?
      end
      wire
    end

    private

    def serialize_wire_value(value)
      case value
      when Time, DateTime then value.iso8601   # DateTime before Date: DateTime < Date
      when Date           then value.strftime('%Y-%m-%d')
      when BigDecimal     then value.to_f
      else value
      end
    end
  end
end
