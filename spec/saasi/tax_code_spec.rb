require 'spec_helper'

describe Saasi::TaxCode do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) { { 'Id' => 11, 'Code' => 'G1', 'Rate' => 10.0, 'IsSale' => true, 'Novel' => 'kept' } }

  it 'round-trips losslessly' do
    expect(Saasi::TaxCode.from_wire(wire).to_wire).to eq wire
  end

  it 'raises the legacy unsupported error on save' do
    expect { Saasi::TaxCode.from_wire(wire).save }.
      to raise_error(RuntimeError, /not currently supported/)
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/taxcodes?FileId=777').
      to_return(status: 200, body: { 'TaxCodes' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
