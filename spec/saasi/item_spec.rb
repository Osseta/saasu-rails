require 'spec_helper'

describe Saasi::Item do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'Id' => 3, 'Code' => 'BOOK', 'Type' => 'C', 'IsActive' => true, 'SaleCoSAccountId' => 12,
      'VType' => 'x', 'SellingPrice' => 25.5,
      'BuildItems' => [{ 'Id' => 4, 'Code' => 'PAGE', 'Quantity' => 100.0 }],
      'Extra' => 'kept' }
  end

  it 'round-trips losslessly (including the irregular wire keys)' do
    expect(Saasi::Item.from_wire(wire).to_wire).to eq wire
  end

  it 'validates the item type enum' do
    expect(Saasi::Item.new(type: 'Z')).not_to be_valid
    expect(Saasi::Item.new(type: 'I')).to be_valid
  end

  it 'delegates build to the legacy endpoint' do
    stub_request(:post, 'https://api.saasu.com/Item/3/build?FileId=777').
      with(body: { Quantity: 5 }).
      to_return(status: 200, body: { StatusMessage: 'Ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

    item = Saasi::Item.from_wire(wire)
    expect(item.build(quantity: 5)['StatusMessage']).to eq 'Ok'
  end
end
