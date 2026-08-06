require 'spec_helper'

describe Saasi::Payment do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'TransactionId' => 44, 'TransactionDate' => '2026-08-01', 'TransactionType' => 'SP',
      'PaymentAccountId' => 456, 'TotalAmount' => 100.0,
      'PaymentItems' => [{ 'InvoiceTransactionId' => 33, 'AmountPaid' => 100.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Payment.from_wire(wire).to_wire).to eq wire
  end

  it 'requires the .NET-required fields and validates the SP/PP enum' do
    payment = Saasi::Payment.new
    expect(payment.valid?).to be false
    expect(payment.errors.attribute_names).to include(:transaction_date, :transaction_type, :payment_account_id, :payment_items)
    expect(Saasi::Payment.from_wire(wire.merge('TransactionType' => 'S'))).not_to be_valid
  end

  it 'uses TransactionId as id' do
    expect(Saasi::Payment.from_wire(wire).id).to eq 44
  end

  it 'lists via the legacy class with metadata' do
    stub_request(:get, 'https://api.saasu.com/payments?FileId=777').
      to_return(status: 200, body: { PaymentTransactions: [wire], Total: 1 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    payments = Saasi::Payment.all
    expect(payments.first.payment_items.first.amount_paid).to eq BigDecimal('100')
    expect(payments.metadata).to eq({ 'Total' => 1 })
  end
end
