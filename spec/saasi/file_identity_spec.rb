require 'spec_helper'

describe Saasi::FileIdentity do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'round-trips (PostCode wire key intact)' do
    wire = { 'Name' => 'My Biz', 'PostCode' => '2000', 'FileSettings' => { 'SaleAmountsIncludeTax' => true }, 'Novel' => 'kept' }
    expect(Saasi::FileIdentity.from_wire(wire).to_wire).to eq wire
  end

  it 'wraps the legacy query-param find' do
    # Faraday merges request params over the URL query string, so the final URL
    # carries a single FileId=888 (the argument wins over Config.file_id)
    stub_request(:get, 'https://api.saasu.com/FileIdentity?FileId=888').
      to_return(status: 200, body: { Name: 'Other Biz' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Saasi::FileIdentity.find(888).name).to eq 'Other Biz'
  end

  it 'returns nil for a blank find response' do
    stub_request(:get, 'https://api.saasu.com/FileIdentity?FileId=888').
      to_return(status: 200, body: '')
    expect(Saasi::FileIdentity.find(888)).to be_nil
  end
end
