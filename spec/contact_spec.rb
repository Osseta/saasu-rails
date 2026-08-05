require 'spec_helper'

describe Saasu::Contact do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  describe "filters" do
    it 'accepts OrganisationName' do
      expect { Saasu::Contact.validate_filters(OrganisationName: 'Acme') }.
        not_to raise_error
    end
  end

  describe "#update" do
    it 'PUTs the merged attributes then refreshes from the API' do
      stub_request(:put, 'https://api.saasu.com/contact/5?FileId=777').
        with(body: { 'Id' => 5, 'GivenName' => 'Jill' }).
        to_return(status: 200, body: { UpdatedContactId: 5 }.to_json, headers: {'Content-Type'=>'application/json'})
      stub_request(:get, 'https://api.saasu.com/contact/5?FileId=777').
        to_return(status: 200, body: { Id: 5, GivenName: 'Jill', LastUpdatedId: 'AAA=' }.to_json, headers: {'Content-Type'=>'application/json'})

      contact = Saasu::Contact.new('Id' => 5, 'GivenName' => 'Jack')
      expect(contact.update('GivenName' => 'Jill')).to be true
      expect(contact.given_name).to eq 'Jill'
      expect(contact['LastUpdatedId']).to eq 'AAA='

      expect(a_request(:put, 'https://api.saasu.com/contact/5?FileId=777')).to have_been_made
    end
  end

  describe "#save on an existing record" do
    it 'PUTs the current attributes to contact/:id' do
      stub_request(:put, 'https://api.saasu.com/contact/5?FileId=777').
        to_return(status: 200, body: { UpdatedContactId: 5 }.to_json, headers: {'Content-Type'=>'application/json'})
      stub_request(:get, 'https://api.saasu.com/contact/5?FileId=777').
        to_return(status: 200, body: { Id: 5, GivenName: 'Jack' }.to_json, headers: {'Content-Type'=>'application/json'})

      contact = Saasu::Contact.new('Id' => 5, 'GivenName' => 'Jack')
      expect(contact.save).to be true

      expect(a_request(:put, 'https://api.saasu.com/contact/5?FileId=777').
        with(body: { 'Id' => 5, 'GivenName' => 'Jack' })).to have_been_made
    end
  end

  describe ".find on a missing record" do
    it 'raises Saasu::NotFoundError' do
      stub_request(:get, 'https://api.saasu.com/contact/999?FileId=777').
        to_return(status: 404, body: '')

      expect { Saasu::Contact.find(999) }.to raise_error(Saasu::NotFoundError)
    end
  end
end
