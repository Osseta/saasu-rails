require 'spec_helper'

describe Saasi::Company do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) { { 'Id' => 2, 'Name' => 'Acme', 'Abn' => '51824753556', 'Novel' => 'kept' } }

  it 'round-trips losslessly' do
    expect(Saasi::Company.from_wire(wire).to_wire).to eq wire
  end

  it 'reads but never writes the deprecated LogoUrl' do
    company = Saasi::Company.from_wire(wire.merge('LogoUrl' => 'http://x/logo.png'))
    expect(company.logo_url).to eq 'http://x/logo.png'
    expect(company.to_wire).to eq wire
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/companies?FileId=777').
      to_return(status: 200, body: { 'Companies' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
