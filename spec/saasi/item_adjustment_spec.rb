require 'spec_helper'

describe Saasi::ItemAdjustment do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'Id' => 12, 'Date' => '2026-08-01', 'Summary' => 'Stocktake',
      'AdjustmentItems' => [{ 'Quantity' => 2.5, 'ItemId' => 3, 'AccountId' => 8, 'UnitPrice' => 10.0, 'TotalPrice' => 25.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::ItemAdjustment.from_wire(wire).to_wire).to eq wire
  end

  it 'types adjustment items' do
    expect(Saasi::ItemAdjustment.from_wire(wire).adjustment_items.first.quantity).to eq BigDecimal('2.5')
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/itemadjustments?FileId=777').
      to_return(status: 200, body: { 'ItemAdjustments' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
