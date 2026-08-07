require 'spec_helper'

describe Saasi::Brand do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'types the full BrandDetail shape' do
    wire = { 'Id' => 1, 'Name' => 'Main', 'IsDefault' => true,
             'UseContactDetailsInFileIdentity' => false, 'WebsiteUrl' => 'https://x',
             'EmailAddress' => 'b@x.com', 'PrimaryPhone' => '02 9999 9999',
             'Street' => '1 Main St', 'City' => 'Sydney', 'PostCode' => '2000',
             'CountryId' => 13 }
    brand = Saasi::Brand.from_wire(wire)
    expect(brand.is_default).to be true
    expect(brand.post_code).to eq '2000'
    expect(brand.country_id).to eq 13
    expect(brand.to_wire).to eq wire
  end

  it 'round-trips with unknown fields in extra' do
    wire = { 'Id' => 1, 'Name' => 'Main', 'LogoBytes' => 'xxx' }
    brand = Saasi::Brand.from_wire(wire)
    expect(brand.extra).to eq({ 'LogoBytes' => 'xxx' })
    expect(brand.to_wire).to eq wire
  end

  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/brands?FileId=777').
      to_return(status: 200, body: { 'Brands' => [{ 'Id' => 1, 'Name' => 'Main' }] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
end
