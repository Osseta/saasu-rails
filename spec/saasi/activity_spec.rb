require 'spec_helper'

describe Saasi::Activity do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'Id' => 6, 'Title' => 'Call Jack', 'Done' => false, 'Due' => '2026-08-10',
      'AttachedToType' => 'Contact', 'AttachedToId' => 5, 'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Activity.from_wire(wire).to_wire).to eq wire
  end

  it 'validates AttachedToType case-insensitively (the API returns lowercase)' do
    expect(Saasi::Activity.new(attached_to_type: 'Planet')).not_to be_valid
    expect(Saasi::Activity.new(attached_to_type: 'Sale')).to be_valid
    expect(Saasi::Activity.new(attached_to_type: 'sale')).to be_valid
    expect(Saasi::Activity.new(attached_to_type: nil)).to be_valid
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/activities?FileId=777').
      to_return(status: 200, body: { 'Activities' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
