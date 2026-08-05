require 'spec_helper'

describe Saasu::Invoice do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  describe "#email" do
    it 'emails a specific address via Invoice/:id/email' do
      stub_request(:post, 'https://api.saasu.com/Invoice/33/email?FileId=777').
        with(body: { EmailTo: 'someone@example.com' }).
        to_return(status: 200, body: { InvoiceId: 33, StatusMessage: 'Ok' }.to_json, headers: {'Content-Type'=>'application/json'})

      invoice = Saasu::Invoice.new('Id' => 33)
      expect(invoice.email('someone@example.com')['StatusMessage']).to eq 'Ok'
    end

    it 'emails the billing contact via Invoice/:id/email-contact when no address given' do
      stub_request(:post, 'https://api.saasu.com/Invoice/33/email-contact?FileId=777').
        with(body: {}).
        to_return(status: 200, body: { InvoiceId: 33, StatusMessage: 'Ok' }.to_json, headers: {'Content-Type'=>'application/json'})

      invoice = Saasu::Invoice.new('Id' => 33)
      expect(invoice.email['StatusMessage']).to eq 'Ok'
    end
  end
end
