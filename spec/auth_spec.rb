require 'spec_helper'

describe Saasu::Auth do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    # Auth memoizes the token module-wide; clear it so this spec exercises the grant request
    Saasu::Auth.instance_variable_set(:@access_token, nil)
    Saasu::Auth.instance_variable_set(:@token_expiry, nil)
  end

  after do
    Saasu::Config.scope = nil
    Saasu::Auth.instance_variable_set(:@access_token, nil)
    Saasu::Auth.instance_variable_set(:@token_expiry, nil)
  end

  describe "two-factor handshake" do
    it 'requests an SMS code via token-2fa without a verification code' do
      stub_request(:post, 'https://api.saasu.com/authorisation/token-2fa').
        with(body: { grant_type: 'password', scope: 'full', username: 'user@saasu.com', password: 'password' }).
        to_return(status: 401, body: { error: '2fa_code_required' }.to_json, headers: {'Content-Type'=>'application/json'})

      expect(Saasu::Auth.request_two_factor_code).to be true
    end

    it 'stores the token and returns false when the account has no 2FA' do
      stub_request(:post, 'https://api.saasu.com/authorisation/token-2fa').
        to_return(status: 200, body: { access_token: 'no2fa-token', refresh_token: 'r', expires_in: 1000 }.to_json,
                  headers: {'Content-Type'=>'application/json'})

      expect(Saasu::Auth.request_two_factor_code).to be false
      expect(Saasu::Auth.instance_variable_get(:@access_token)).to eq 'no2fa-token'
    end

    it 'raises TwoFactorRequiredError when a plain grant is rejected pending 2FA' do
      stub_request(:post, 'https://api.saasu.com/authorisation/token').
        to_return(status: 401, body: { error: '2fa_code_required' }.to_json, headers: {'Content-Type'=>'application/json'})

      expect { Saasu::Auth.authenticate }.to raise_error(Saasu::TwoFactorRequiredError)
    end
  end

  describe "token refresh" do
    it 'refreshes an expired token instead of re-requesting a password grant' do
      Saasu::Auth.instance_variable_set(:@access_token, 'stale-token')
      Saasu::Auth.instance_variable_set(:@refresh_token, 'refresh-me')
      Saasu::Auth.instance_variable_set(:@token_expiry, DateTime.now - 1)

      stub_request(:post, 'https://api.saasu.com/authorisation/refresh').
        with(body: { grant_type: 'refresh_token', refresh_token: 'refresh-me' }).
        to_return(status: 200, body: { access_token: 'fresh-token', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})

      Saasu::Auth.authenticate

      expect(a_request(:post, 'https://api.saasu.com/authorisation/refresh')).to have_been_made
      expect(a_request(:post, 'https://api.saasu.com/authorisation/token')).not_to have_been_made
      expect(Saasu::Auth.instance_variable_get(:@access_token)).to eq 'fresh-token'
    end

    it 'raises when the refresh is rejected' do
      Saasu::Auth.instance_variable_set(:@access_token, 'stale-token')
      Saasu::Auth.instance_variable_set(:@refresh_token, 'refresh-me')
      Saasu::Auth.instance_variable_set(:@token_expiry, DateTime.now - 1)

      stub_request(:post, 'https://api.saasu.com/authorisation/refresh').
        to_return(status: 401, body: '')

      expect { Saasu::Auth.authenticate }.to raise_error(RuntimeError, /Failed to authenicate/)
    end
  end

  describe "configurable OAuth scope" do
    it 'requests the configured scope, including fileid context scopes' do
      Saasu::Config.scope = 'view fileid:1234'

      stub_request(:post, 'https://api.saasu.com/authorisation/token').
        with(body: { grant_type: 'password', scope: 'view fileid:1234', username: 'user@saasu.com', password: 'password' }).
        to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})

      Saasu::Auth.authenticate

      expect(a_request(:post, 'https://api.saasu.com/authorisation/token').
        with(body: hash_including('scope' => 'view fileid:1234'))).to have_been_made
    end

    it 'defaults to the full scope' do
      stub_request(:post, 'https://api.saasu.com/authorisation/token').
        with(body: { grant_type: 'password', scope: 'full', username: 'user@saasu.com', password: 'password' }).
        to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})

      Saasu::Auth.authenticate

      expect(a_request(:post, 'https://api.saasu.com/authorisation/token').
        with(body: hash_including('scope' => 'full'))).to have_been_made
    end
  end
end
