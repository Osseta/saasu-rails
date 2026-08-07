module Saasu
  # Array of records plus the rest of the response envelope (paging, totals)
  class Collection < Array
    attr_reader :metadata

    def initialize(records, metadata = {})
      super(records)
      @metadata = metadata
    end
  end

  class Base
    attr_reader :attributes

    def initialize(params = {})
      @attributes = params.deep_stringify_keys
    end

    def self.all
      validate_method_is_implemented_in_saasu_api(:index)

      build_collection(Saasu::Client.request(:get, resource_url.pluralize))
    end

    def self.find(id)
      validate_method_is_implemented_in_saasu_api(:show)

      response = Saasu::Client.request(:get, resource_url(id))

      self.new(response) if response.present?
    end

    def self.where(params)
      validate_method_is_implemented_in_saasu_api(:index)
      validate_filters(params)

      build_collection(Saasu::Client.request(:get, resource_url.pluralize, params))
    end

    def delete
      validate_method_is_implemented_in_saasu_api(:destroy)

      response = Saasu::Client.request(:delete, self.class.resource_url(id))
      if response.is_a?(Hash) && response["StatusMessage"] == "Ok"
        self['Id'] = nil
        true
      else
        false
      end
    end

    def self.delete(id)
      validate_method_is_implemented_in_saasu_api(:destroy)

      Saasu::Client.request(:delete, resource_url(id))
    end

    def save
      # _links is response-only hypermedia the API forbids sending back
      payload = @attributes.except('_links')

      if self.id.present?
        validate_method_is_implemented_in_saasu_api(:update)
        Saasu::Client.request(:put, self.class.resource_url(id), payload)
      else
        validate_method_is_implemented_in_saasu_api(:create)
        self['Id'] = self.class.extract_inserted_id(Saasu::Client.request(:post, self.class.resource_url, payload))
      end

      @attributes = Saasu::Client.request(:get, self.class.resource_url(id))
      true
    end

    def update(params)
      validate_method_is_implemented_in_saasu_api(:update)

      params.each do |key, value|
        self[key] = value
      end

      save
    end

    def self.create(params)
      validate_method_is_implemented_in_saasu_api(:create)

      id = extract_inserted_id(Saasu::Client.request(:post, resource_url, params))
      new(Saasu::Client.request(:get, resource_url(id)))
    end

    def validate_method_is_implemented_in_saasu_api(method_name)
      self.class.validate_method_is_implemented_in_saasu_api(method_name)
    end

    def self.validate_method_is_implemented_in_saasu_api(method_name)
      raise "This method is not currently supported by Saasu API" unless (@api_methods || []).include?(method_name)
    end

    def [](key)
      @attributes[key.to_s]
    end

    def []=(key, value)
      @attributes[key.to_s] = value
    end

    def method_missing meth, *args, &cb
      if meth.in?(getter_methods)
        @attributes[meth.to_s.camelize]
      elsif meth.in?(setter_methods)
        @attributes[meth.to_s.gsub('=','').camelize] = args.first
      else
        super meth, *args, &cb
      end
    end

    def to_s
      "#{self.class.name.demodulize} ##{self.id}"
    end

    def id
      @attributes.has_key?('Id') ? @attributes['Id'] : @attributes['TransactionId']
    end

    protected
    def getter_methods
      @attributes.keys.map { |k| k.underscore.to_sym }
    end

    def setter_methods
      @attributes.keys.map { |k| "#{k.underscore}=".to_sym }
    end

    def self.allowed_methods(*params)
      @api_methods = params
    end

    def self.filter_by(params)
      @filters = params
    end

    def self.collection_key(key = nil)
      @collection_key = key if key
      @collection_key || name.demodulize.pluralize
    end

    def self.resource_url(id = nil)
      [name.demodulize.downcase, id].compact.join('/')
    end

    def self.validate_filters(params)
      filters = @filters || []
      params.keys.each do |key|
        raise "Filter not supported by Saasu API: #{key}. Supported filters: #{filters.join(", ")}" unless key.to_s.in?(filters)
      end
    end

    def self.build_collection(response)
      key = if response.key?(collection_key)
              collection_key
            else
              # legacy responses were unwrapped positionally; prefer the first array value
              response.keys.find { |k| response[k].is_a?(Array) } || response.keys.first
            end

      records = Array(response[key]).map { |record| new(record) }
      Collection.new(records, response.except(key))
    end

    def self.extract_inserted_id(response)
      return nil unless response.is_a?(Hash)

      response['InsertedEntityId'] || response['Id'] || response.values.first
    end
  end
end
