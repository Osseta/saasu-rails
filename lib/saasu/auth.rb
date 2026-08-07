require 'faraday'
require 'faraday_middleware'

module Saasu
  module Auth
    extend self

    def authenticate
      Saasu::Client.connection.authorization :Bearer, token
    end

    def ping
      Saasu::Client.request(:get, 'authorisation/ping')
    end

    # Trigger the documented 2FA handshake: POST token-2fa WITHOUT a code makes
    # the API SMS a one-time code to the account's mobile and reply
    # 401 2fa_code_required. Returns true when the SMS was triggered (then set
    # Config.two_factor_code and call authenticate); returns false when the
    # account has no 2FA (the token from the response is stored directly).
    def request_two_factor_code
      result = Saasu::Client.connection.post('authorisation/token-2fa') do |request|
        request.body = grant_request_body.to_json
      end

      return true if two_factor_required?(result)

      if result.status == 200
        store_grant(result.body)
        false
      else
        raise "Failed to authenicate Saasu API. Please check your username and password."
      end
    end

    private
    def token_expired?
      @token_expiry ||= Date.yesterday
      @token_expiry < DateTime.now
    end

    def token
      if @access_token && !token_expired?
        @access_token
      elsif @access_token && token_expired?
        refresh_access_token
      else
        get_access_token
      end
    end

    def refresh_access_token
      result = Saasu::Client.connection.post('authorisation/refresh') do |request|
        request.body = { grant_type: 'refresh_token', refresh_token: @refresh_token }.to_json
      end

      # refresh tokens expire after 12 months — fall back to a fresh password
      # grant rather than stranding long-lived integrations
      return get_access_token unless result.status == 200

      @access_token = result.body['access_token']
      @token_expiry = DateTime.now + (result.body['expires_in']).to_i.seconds

      @access_token
    end

    def get_access_token
      if Saasu::Config.two_factor_code.present?
        url = 'authorisation/token-2fa'
        body = grant_request_body.merge(verification_code: Saasu::Config.two_factor_code)
      else
        url = 'authorisation/token'
        body = grant_request_body
      end

      result = Saasu::Client.connection.post(url) do |request|
        request.body = body.to_json
      end

      unless result.status == 200
        if two_factor_required?(result)
          raise Saasu::TwoFactorRequiredError.new(
            'Two-factor verification required. Call Saasu::Auth.request_two_factor_code to receive an SMS code, then set Saasu::Config.two_factor_code and retry.',
            status: result.status, body: result.body
          )
        end
        raise "Failed to authenicate Saasu API. Please check your username and password."
      end

      store_grant(result.body)
    end

    def grant_request_body
      { grant_type: 'password', scope: Saasu::Config.scope.presence || 'full',
        username: Saasu::Config.username, password: Saasu::Config.password }
    end

    def two_factor_required?(result)
      result.body.is_a?(Hash) && result.body['error'].to_s.include?('2fa_code_required')
    end

    def store_grant(body)
      @access_token = body['access_token']
      @refresh_token = body['refresh_token']
      @token_expiry = DateTime.now + (body['expires_in']).to_i.seconds

      @access_token
    end
  end
end
