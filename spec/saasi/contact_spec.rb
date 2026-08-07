require 'spec_helper'

describe Saasi::Contact do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    {
      'Id' => 5, 'GivenName' => 'Jack', 'FamilyName' => 'Sparrow', 'IsActive' => true,
      'ContactId' => 'CUST-001', 'Tags' => ['vip'],
      'PostalAddress' => { 'Street' => '1 Main St', 'City' => 'Sydney', 'Postcode' => '2000' },
      'DirectDepositDetails' => { 'AcceptDirectDeposit' => true, 'AccountBSB' => '062-000' },
      'BpayDetails' => { 'BillerCode' => '1234', 'CRN' => '999' },
      'SaleTradingTerms' => { 'TradingTermsType' => 1, 'TradingTermsInterval' => 14, 'TradingTermsIntervalType' => 1 },
      'NewField' => 'kept'
    }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Contact.from_wire(wire).to_wire).to eq wire
  end

  it 'types nested value objects and keeps ContactId a string' do
    contact = Saasi::Contact.from_wire(wire)
    expect(contact.contact_id).to eq 'CUST-001'
    expect(contact.postal_address.city).to eq 'Sydney'
    expect(contact.direct_deposit_details.account_bsb).to eq '062-000'
    expect(contact.bpay_details.crn).to eq '999'
    expect(contact.sale_trading_terms.trading_terms_interval).to eq 14
  end

  it 'validates salutation' do
    expect(Saasi::Contact.new(salutation: 'Lord')).not_to be_valid
    expect(Saasi::Contact.new(salutation: 'Dr.')).to be_valid
  end

  it 'generates a statement PDF with the documented params' do
    stub_request(:get, 'https://api.saasu.com/Contact/5/generate-pdf?FileId=777&GenerateType=Statement&FromDate=2026-07-01&ToDate=2026-07-31').
      to_return(status: 200, body: 'PDF')

    contact = Saasi::Contact.from_wire(wire)
    expect(contact.generate_pdf(from_date: '2026-07-01', to_date: '2026-07-31')).to eq 'PDF'
  end

  it 'creates via the legacy class' do
    stub_request(:post, 'https://api.saasu.com/contact?FileId=777').
      with(body: { GivenName: 'Jack' }).
      to_return(status: 200, body: { InsertedEntityId: 9 }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.saasu.com/contact/9?FileId=777').
      to_return(status: 200, body: { Id: 9, GivenName: 'Jack' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Saasi::Contact.create(given_name: 'Jack').id).to eq 9
  end
end
