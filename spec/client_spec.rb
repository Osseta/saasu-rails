require 'spec_helper'

describe Saasu::Client do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  describe ".request" do
    it 'treats 201 as success and returns the body' do
      stub_request(:post, 'https://api.saasu.com/clienttest?FileId=777').
        to_return(status: 201, body: { Id: 9 }.to_json, headers: {'Content-Type'=>'application/json'})

      expect(Saasu::Client.request(:post, 'clienttest', { Name: 'x' })).to eq({ "Id" => 9 })
    end

    it 'treats 204 as success and returns nil' do
      stub_request(:delete, 'https://api.saasu.com/clienttest/9?FileId=777').
        to_return(status: 204, body: '')

      expect(Saasu::Client.request(:delete, 'clienttest/9')).to be_blank
    end

    it 'raises Saasu::NotFoundError on 404 with the legacy message' do
      stub_request(:get, 'https://api.saasu.com/clienttest/1?FileId=777').
        to_return(status: 404, body: '')

      expect { Saasu::Client.request(:get, 'clienttest/1') }.
        to raise_error(Saasu::NotFoundError, "Resource not found.")
    end

    it 'raises Saasu::Error carrying status and body on other failures' do
      stub_request(:get, 'https://api.saasu.com/clienttest/1?FileId=777').
        to_return(status: 500, body: { Errors: ['boom'] }.to_json, headers: {'Content-Type'=>'application/json'})

      expect { Saasu::Client.request(:get, 'clienttest/1') }.to raise_error(Saasu::Error) do |error|
        expect(error.status).to eq 500
        expect(error.body).to eq({ "Errors" => ["boom"] })
      end
    end

    it 'remains rescuable as RuntimeError for backwards compatibility' do
      expect(Saasu::Error.ancestors).to include(RuntimeError)
    end
  end
end
