require 'spec_helper'

describe "additions to existing classes" do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777
    Saasu::Config.two_factor_code = nil

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  it 'Account.bank_account_balances hits Accounts/BankAccountBalances' do
    stub_request(:get, "https://api.saasu.com/Accounts/BankAccountBalances?FileId=777").
      to_return(status: 200, body: { BankAccounts: [] }.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::Account.bank_account_balances).to have_key('BankAccounts')
  end

  it 'Contact#generate_pdf hits Contact/id/generate-pdf' do
    stub_request(:get, "https://api.saasu.com/Contact/5/generate-pdf?FileId=777").
      to_return(status: 200, body: 'PDF'.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::Contact.new(Id: 5).generate_pdf).to eq 'PDF'
  end

  it 'Invoice.sales_stats_summary hits Invoices/SalesStatsSummary' do
    stub_request(:get, "https://api.saasu.com/Invoices/SalesStatsSummary?FileId=777").
      to_return(status: 200, body: { TotalSales: 10 }.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::Invoice.sales_stats_summary['TotalSales']).to eq 10
  end

  it 'Item#build hits POST Item/id/build' do
    stub_request(:post, "https://api.saasu.com/Item/5/build?FileId=777").
      to_return(status: 200, body: { Id: 5 }.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::Item.new(Id: 5).build['Id']).to eq 5
  end

  it 'InvoiceAttachment.for_invoice maps Attachments envelope' do
    stub_request(:get, "https://api.saasu.com/InvoiceAttachments/99?FileId=777").
      to_return(status: 200, body: { Attachments: [{ Id: 1 }, { Id: 2 }] }.to_json, headers: {'Content-Type'=>'application/json'})
    result = Saasu::InvoiceAttachment.for_invoice(99)
    expect(result.map(&:id)).to eq [1, 2]
  end

  it 'InvoiceAttachment no longer allows update' do
    expect { Saasu::InvoiceAttachment.new(Id: 1).update(Name: 'x') }.to raise_error(RuntimeError)
  end

  it 'FileIdentity.update hits PUT FileIdentity' do
    stub_request(:put, "https://api.saasu.com/FileIdentity?FileId=777").
      to_return(status: 200, body: { StatusMessage: 'Ok' }.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::FileIdentity.update(Name: 'Acme')['StatusMessage']).to eq 'Ok'
  end

  it 'User.current hits GET User' do
    stub_request(:get, "https://api.saasu.com/User?FileId=777").
      to_return(status: 200, body: { EmailAddress: 'a@b.com' }.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::User.current['EmailAddress']).to eq 'a@b.com'
  end

  it 'User.update hits PUT User' do
    stub_request(:put, "https://api.saasu.com/User?FileId=777").
      to_return(status: 200, body: { StatusMessage: 'Ok' }.to_json, headers: {'Content-Type'=>'application/json'})
    Saasu::User.update(EmailAddress: 'a@b.com')
    expect(a_request(:put, "https://api.saasu.com/User?FileId=777")).to have_been_made
  end

  it 'User 2FA endpoints hit the right paths' do
    %w(opt-in-to-2fa opt-out-from-2fa verify-2fa-opt-in).each do |p|
      stub_request(:post, "https://api.saasu.com/User/#{p}?FileId=777").
        to_return(status: 200, body: {}.to_json, headers: {'Content-Type'=>'application/json'})
    end
    Saasu::User.opt_in_to_2fa(MobileNumber: '0400000000')
    Saasu::User.opt_out_from_2fa
    Saasu::User.verify_2fa_opt_in(VerificationCode: '123')
    expect(a_request(:post, "https://api.saasu.com/User/opt-in-to-2fa?FileId=777")).to have_been_made
    expect(a_request(:post, "https://api.saasu.com/User/opt-out-from-2fa?FileId=777")).to have_been_made
    expect(a_request(:post, "https://api.saasu.com/User/verify-2fa-opt-in?FileId=777")).to have_been_made
  end

  it 'Auth.ping hits GET authorisation/ping' do
    stub_request(:get, "https://api.saasu.com/authorisation/ping?FileId=777").
      to_return(status: 200, body: { Ok: true }.to_json, headers: {'Content-Type'=>'application/json'})
    expect(Saasu::Auth.ping).to have_key('Ok')
  end

  it '2FA token uses authorisation/token-2fa when two_factor_code is set' do
    Saasu::Auth.instance_variable_set(:@access_token, nil)
    Saasu::Config.two_factor_code = '654321'
    stub_request(:post, 'https://api.saasu.com/authorisation/token-2fa').
      with(body: hash_including('verification_code' => '654321')).
      to_return(status: 200, body: { access_token: 'tfa', refresh_token: 'r', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
    stub_request(:get, "https://api.saasu.com/authorisation/ping?FileId=777").
      to_return(status: 200, body: {}.to_json, headers: {'Content-Type'=>'application/json'})
    Saasu::Auth.ping
    expect(a_request(:post, 'https://api.saasu.com/authorisation/token-2fa')).to have_been_made
    Saasu::Auth.instance_variable_set(:@access_token, nil)
  end
end
