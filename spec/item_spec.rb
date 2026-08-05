require 'spec_helper'

describe Saasu::Item do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  describe ".where" do
    it 'accepts Page and SearchText filters' do
      stub_request(:get, 'https://api.saasu.com/items?FileId=777&Page=1&SearchMethod=Contains&SearchText=abc').
        to_return(status: 200, body: { Items: [] }.to_json, headers: {'Content-Type'=>'application/json'})

      expect { Saasu::Item.where(Page: 1, SearchMethod: 'Contains', SearchText: 'abc') }.
        not_to raise_error
    end
  end
end
