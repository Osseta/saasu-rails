require 'spec_helper'

describe Saasi::FileIdentity do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'round-trips writable fields (PostCode wire key intact)' do
    wire = { 'Name' => 'My Biz', 'PostCode' => '2000', 'IndustryTypeId' => 7,
             'TaxRegistrationDate' => '2000-07-01', 'LastUpdatedId' => 'AAA=',
             'FinancialYearEndMonth' => 6, 'Novel' => 'kept' }
    identity = Saasi::FileIdentity.from_wire(wire)
    expect(identity.industry_type_id).to eq 7
    expect(identity.tax_registration_date).to eq Date.new(2000, 7, 1)
    expect(identity.to_wire).to eq wire
  end

  it 'reads but never writes the immutable/deprecated fields' do
    wire = { 'Name' => 'My Biz', 'Zone' => 'Australia', 'CurrencyCode' => 'AUD',
             'CreatedDateUtc' => '2020-01-01T00:00:00Z',
             'FileSettings' => { 'SaleAmountsIncludeTax' => true,
                                 'SaleTradingTerms' => { 'TradingTermsType' => 1, 'TradingTermsInterval' => 14 } } }
    identity = Saasi::FileIdentity.from_wire(wire)
    expect(identity.zone).to eq 'Australia'
    expect(identity.file_settings.sale_trading_terms.trading_terms_interval).to eq 14
    expect(identity.to_wire).to eq({ 'Name' => 'My Biz' })
  end

  it 'wraps the legacy query-param find' do
    # Faraday merges request params over the URL query string, so the final URL
    # carries a single FileId=888 (the argument wins over Config.file_id)
    stub_request(:get, 'https://api.saasu.com/FileIdentity?FileId=888').
      to_return(status: 200, body: { Name: 'Other Biz' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Saasi::FileIdentity.find(888).name).to eq 'Other Biz'
  end

  it 'returns nil for a blank find response' do
    stub_request(:get, 'https://api.saasu.com/FileIdentity?FileId=888').
      to_return(status: 200, body: '')
    expect(Saasi::FileIdentity.find(888)).to be_nil
  end
end
