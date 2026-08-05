require 'faraday'
require 'faraday_middleware'

module Saasu
  # RuntimeError parent keeps pre-existing `rescue RuntimeError` callers working
  class Error < RuntimeError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class NotFoundError < Error; end

  class Client
    class_attribute :connection

    class << self
      def request(method, url, params = {}, authenticate: true)
        request_url = if authenticate
          Saasu::Auth.authenticate
          url + "?FileId=#{Saasu::Config.file_id}"
        else
          url
        end

        response = connection.send(method, request_url, params) do |req|
          # the shared connection carries the Bearer header from earlier authenticated calls
          req.headers.delete('Authorization') unless authenticate
        end

        if (200..299).cover?(response.status)
          response.body
        elsif response.status == 404
          raise NotFoundError.new("Resource not found.", status: response.status, body: response.body)
        else
          raise Error.new("Server did not return a valid response. URL: #{request_url}. Response status: #{response.status}. Response body: #{response.body}",
                          status: response.status, body: response.body)
        end
      end

      def connection
        @@connection ||= initialize_connection
      end

      private
      def initialize_connection
        con = Faraday.new(url: api_url) do |c|
          c.request :json

          c.response :json, :content_type => /\bjson$/

          c.use :instrumentation
          c.adapter  Faraday.default_adapter
        end

        con.headers['X-Api-Version'] = '1.0'
        con
      end

      def api_url
        Saasu::Config.api_url || 'https://api.saasu.com/'
      end
    end
  end
end
