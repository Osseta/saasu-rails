require 'spec_helper'

describe Saasi::ItemTransfer do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'Id' => 13, 'Date' => '2026-08-01',
      'Items' => [{ 'Quantity' => 1.0, 'InventoryItemId' => 3, 'UnitCost' => 9.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::ItemTransfer.from_wire(wire).to_wire).to eq wire
  end

  it 'requires date and items' do
    transfer = Saasi::ItemTransfer.new
    expect(transfer.valid?).to be false
    expect(transfer.errors.attribute_names).to include(:date, :items)
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/itemtransfers?FileId=777').
      to_return(status: 200, body: { 'Transfers' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
