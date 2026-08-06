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

  describe "#add_quick_payment" do
    it 'writes the correctly-cased QuickPayment hash, coercing dates and omitting blanks' do
      invoice = Saasu::Invoice.new
      result = invoice.add_quick_payment(date_paid: Date.new(2026, 8, 6), banked_to_account_id: 456, amount: 100.5, reference: 'chq 12')

      expect(result).to be invoice
      expect(invoice['QuickPayment']).to eq({
        'DatePaid'          => '2026-08-06',
        'BankedToAccountId' => 456,
        'Amount'            => 100.5,
        'Reference'         => 'chq 12'
      })
    end

    it 'requires date_paid, banked_to_account_id and amount' do
      expect { Saasu::Invoice.new.add_quick_payment(amount: 1) }.to raise_error(ArgumentError)
    end

    it 'rejects unknown keywords' do
      expect {
        Saasu::Invoice.new.add_quick_payment(date_paid: '2026-08-06', banked_to_account_id: 1, amount: 1, banked_account: 2)
      }.to raise_error(ArgumentError)
    end

    it 'rejects amounts with more than 2 decimal places' do
      expect {
        Saasu::Invoice.new.add_quick_payment(date_paid: '2026-08-06', banked_to_account_id: 1, amount: 10.005)
      }.to raise_error(ArgumentError, /2 decimal/)
    end

    it 'rejects a quick payment on an already-persisted invoice (API supports POST only)' do
      invoice = Saasu::Invoice.new('Id' => 33)
      expect {
        invoice.add_quick_payment(date_paid: '2026-08-06', banked_to_account_id: 1, amount: 1)
      }.to raise_error(RuntimeError, /POST|creat/i)
    end
  end

  describe "#email_on_save" do
    it 'sets SendEmailToContact and the EmailMessage fields' do
      invoice = Saasu::Invoice.new
      result = invoice.email_on_save(subject: 'Your invoice', body: 'Thanks!', cc: 'copy@example.com')

      expect(result).to be invoice
      expect(invoice['SendEmailToContact']).to be true
      expect(invoice['EmailMessage']).to eq({
        'Subject' => 'Your invoice',
        'Body'    => 'Thanks!',
        'Cc'      => 'copy@example.com'
      })
    end

    it 'sets only the flag when no message fields are given (API uses the default template)' do
      invoice = Saasu::Invoice.new
      invoice.email_on_save

      expect(invoice['SendEmailToContact']).to be true
      expect(invoice['EmailMessage']).to be_nil
    end

    it 'rejects unknown keywords' do
      expect { Saasu::Invoice.new.email_on_save(subjectt: 'typo') }.to raise_error(ArgumentError)
    end
  end
end
