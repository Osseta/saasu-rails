require 'spec_helper'

describe Saasi::ContactAggregate do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'Id' => 5, 'GivenName' => 'Jack',
      'Company' => { 'Id' => 2, 'Name' => 'Acme', 'Abn' => '51824753556' },
      'ContactManager' => { 'Id' => 7, 'GivenName' => 'Boss' },
      'PostalAddress' => { 'Street' => '1 Main St', 'Postcode' => '2000' },
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::ContactAggregate.from_wire(wire).to_wire).to eq wire
  end

  it 'types the three nested objects' do
    aggregate = Saasi::ContactAggregate.from_wire(wire)
    expect(aggregate.company.name).to eq 'Acme'
    expect(aggregate.contact_manager.given_name).to eq 'Boss'
    expect(aggregate.postal_address.postcode).to eq '2000'
  end

  it 'raises the legacy unsupported error on list' do
    expect { Saasi::ContactAggregate.all }.to raise_error(RuntimeError, /not currently supported/)
  end

  it 'finds via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/contactaggregate/5?FileId=777').
      to_return(status: 200, body: wire.to_json, headers: { 'Content-Type' => 'application/json' })
    expect(described_class.find(5).given_name).to eq 'Jack'
  end
end
