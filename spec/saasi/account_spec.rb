require 'spec_helper'

describe Saasi::Account do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'Id' => 8, 'Name' => 'Sales', 'AccountType' => 'Income', 'AccountLevel' => 'Detail',
      'BSB' => '062-000', 'IsBankAccount' => false, 'Novel' => 'kept' }
  end

  it 'round-trips losslessly (BSB wire key intact)' do
    expect(Saasi::Account.from_wire(wire).to_wire).to eq wire
  end

  it 'validates account type and level' do
    expect(Saasi::Account.new(account_type: 'Fun')).not_to be_valid
    expect(Saasi::Account.new(account_type: 'Cost of Sales', account_level: 'Header')).to be_valid
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/accounts?FileId=777').
      to_return(status: 200, body: { 'Accounts' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
