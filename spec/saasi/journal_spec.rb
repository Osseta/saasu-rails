require 'spec_helper'

describe Saasi::Journal do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'TransactionId' => 71, 'TransactionDate' => '2026-07-01', 'Summary' => 'Accrual',
      'Items' => [{ 'Type' => 'Debit', 'AccountId' => 8, 'Amount' => 50.0 },
                  { 'Type' => 'Credit', 'AccountId' => 9, 'Amount' => 50.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Journal.from_wire(wire).to_wire).to eq wire
  end

  it 'requires date and items; validates item type' do
    journal = Saasi::Journal.new
    expect(journal.valid?).to be false
    expect(journal.errors.attribute_names).to include(:transaction_date, :items)
    expect(Saasi::Journal::JournalItem.new(type: 'Sideways')).not_to be_valid
  end

  it 'uses TransactionId as id' do
    expect(Saasi::Journal.from_wire(wire).id).to eq 71
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/journals?FileId=777').
      to_return(status: 200, body: { 'Journals' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
