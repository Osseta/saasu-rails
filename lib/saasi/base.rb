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

      # ActiveModel::Error#message needs model_name, which raises on anonymous
      # classes (e.g. Class.new(Saasi::Base) in specs). Fall back to a stable name.
      def model_name
        ActiveModel::Name.new(self, nil, name || 'Saasi::Base')
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

      def nested_map
        @nested_map ||= superclass.respond_to?(:nested_map) ? superclass.nested_map.dup : {}
      end

      def read_only_names
        @read_only_names ||= superclass.respond_to?(:read_only_names) ? superclass.read_only_names.dup : []
      end

      def read_only(*names)
        read_only_names.concat(names.map(&:to_sym))
      end

      def has_one(name, klass, wire_key: nil)
        nested_map[wire_key || name.to_s.camelize] = { name: name, klass: klass, many: false }
        attr_reader name
        define_method("#{name}=") do |value|
          value = klass.from_wire(value.stringify_keys) if value.is_a?(Hash)
          instance_variable_set("@#{name}", value)
        end
      end

      def has_many(name, klass, wire_key: nil)
        nested_map[wire_key || name.to_s.camelize] = { name: name, klass: klass, many: true }
        define_method(name) do
          instance_variable_get("@#{name}") || instance_variable_set("@#{name}", [])
        end
        define_method("#{name}=") do |values|
          coerced = Array(values).map { |v| v.is_a?(Hash) ? klass.from_wire(v.stringify_keys) : v }
          instance_variable_set("@#{name}", coerced)
        end
      end
    end

    validate :nested_models_are_valid

    def nested_models_are_valid
      self.class.nested_map.each_value do |nested|
        Array(public_send(nested[:name])).each_with_index do |model, index|
          next if model.valid?
          model.errors.each do |error|
            errors.add(nested[:name], "#{index}: #{error.attribute} #{error.message}")
          end
        end
      end
    end

    def assign_wire(hash)
      hash.each do |key, value|
        key = key.to_s
        if (nested = self.class.nested_map[key])
          public_send("#{nested[:name]}=", value)
        elsif (attr_name = self.class.wire_map[key])
          public_send("#{attr_name}=", value)
        elsif self.class.attribute_types.key?(key) || self.class.nested_map.any? { |_, n| n[:name].to_s == key }
          # snake_case attribute or nested name (user-supplied hash, e.g. quick_payment = { date_paid: ... })
          public_send("#{key}=", value)
        else
          extra[key] = value
        end
      end
      self
    end

    def to_wire
      # declared keys always win over stray extra entries, even when the declared value is nil
      wire = extra.reject { |key, _| self.class.wire_map.key?(key) || self.class.nested_map.key?(key) }
      self.class.wire_map.each do |key, attr_name|
        next if self.class.read_only_names.include?(attr_name)
        value = public_send(attr_name)
        wire[key] = serialize_wire_value(value) unless value.nil?
      end
      self.class.nested_map.each do |key, nested|
        next if self.class.read_only_names.include?(nested[:name])
        value = public_send(nested[:name])
        if nested[:many]
          wire[key] = value.map(&:to_wire) unless value.empty?
        elsif value
          wire[key] = value.to_wire
        end
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
