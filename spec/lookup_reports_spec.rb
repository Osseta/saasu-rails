require 'spec_helper'

describe "LookupData and Reports" do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  def stub_get(path, body)
    stub_request(:get, "https://api.saasu.com/#{path}?FileId=777").
      to_return(status: 200, body: body.to_json, headers: {'Content-Type'=>'application/json'})
  end

  it 'LookupData.countries hits LookupData/Countries' do
    stub_get('LookupData/Countries', { Countries: ['AU'] })
    expect(Saasu::LookupData.countries['Countries']).to eq ['AU']
  end

  it 'LookupData.currencies hits LookupData/Currencies' do
    stub_get('LookupData/Currencies', { Currencies: ['AUD'] })
    expect(Saasu::LookupData.currencies['Currencies']).to eq ['AUD']
  end

  it 'LookupData.zones hits LookupData/Zones' do
    stub_get('LookupData/Zones', { Zones: [] })
    expect(Saasu::LookupData.zones).to have_key('Zones')
  end

  it 'Reports.profit_and_loss_summary hits Reports/ProfitAndLoss/Summary' do
    stub_get('Reports/ProfitAndLoss/Summary', { NetProfit: 100 })
    expect(Saasu::Reports.profit_and_loss_summary['NetProfit']).to eq 100
  end

  it 'Reports.profit_and_loss_summary_by_account_type hits SummaryByAccountType' do
    stub_get('Reports/ProfitAndLoss/SummaryByAccountType', { NetProfit: 200 })
    expect(Saasu::Reports.profit_and_loss_summary_by_account_type['NetProfit']).to eq 200
  end
end
