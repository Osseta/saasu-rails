require 'spec_helper'

describe "new Base-pattern resources" do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  def stub_index(path, key)
    stub_request(:get, "https://api.saasu.com/#{path}?FileId=777").
      to_return(status: 200, body: { key => [{ Id: 1 }] }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  it 'Activity#all hits GET activities' do
    stub_index('activities', 'Activities')
    expect(Saasu::Activity.all.first.id).to eq 1
  end

  it 'Journal#all hits GET journals' do
    stub_index('journals', 'Journals')
    expect(Saasu::Journal.all.first.id).to eq 1
  end

  it 'ItemAdjustment#all hits GET itemadjustments' do
    stub_index('itemadjustments', 'ItemAdjustments')
    expect(Saasu::ItemAdjustment.all.count).to eq 1
  end

  it 'ItemTransfer#all hits GET itemtransfers' do
    stub_index('itemtransfers', 'ItemTransfers')
    expect(Saasu::ItemTransfer.all.count).to eq 1
  end

  it 'Brand#all hits GET brands' do
    stub_index('brands', 'Brands')
    expect(Saasu::Brand.all.count).to eq 1
  end

  it 'DeletedEntity#all hits GET deletedentities' do
    stub_index('deletedentities', 'DeletedEntities')
    expect(Saasu::DeletedEntity.all.count).to eq 1
  end

  it 'DeletedEntity#where validates filters and passes params' do
    stub_request(:get, "https://api.saasu.com/deletedentities?FileId=777&EntityType=Invoice").
      to_return(status: 200, body: { DeletedEntities: [{ Id: 9 }] }.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::DeletedEntity.where(EntityType: 'Invoice').first.id).to eq 9
    expect { Saasu::DeletedEntity.where(Bogus: 1) }.to raise_error(RuntimeError)
  end
end
