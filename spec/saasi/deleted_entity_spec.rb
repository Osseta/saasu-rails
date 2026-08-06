require 'spec_helper'

describe Saasi::DeletedEntity do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) { { 'EntityType' => 'Sale', 'EntityId' => 33, 'DeletedByUser' => 'jack', 'Timestamp' => '2026-08-01T00:00:00Z', 'Novel' => 'kept' } }

  it 'round-trips losslessly' do
    expect(Saasi::DeletedEntity.from_wire(wire).to_wire).to eq wire
  end

  it 'validates entity type' do
    expect(Saasi::DeletedEntity.new(entity_type: 'Unicorn')).not_to be_valid
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/deletedentities?FileId=777').
      to_return(status: 200, body: { 'Entities' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
