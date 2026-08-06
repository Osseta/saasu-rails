require 'spec_helper'
require 'base64'
require 'stringio'

describe Saasi::InvoiceAttachment do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'round-trips and decodes attachment data' do
    wire = { 'Id' => 9, 'Name' => 'inv.pdf', 'AttachmentData' => Base64.strict_encode64('PDF'), 'Novel' => 'kept' }
    attachment = Saasi::InvoiceAttachment.from_wire(wire)
    expect(attachment.decoded_data).to eq 'PDF'
    expect(attachment.to_wire).to eq wire
  end

  it 'lists typed attachments for an invoice' do
    stub_request(:get, 'https://api.saasu.com/InvoiceAttachments/33?FileId=777').
      to_return(status: 200, body: { Attachments: [{ Id: 9, Name: 'inv.pdf' }] }.to_json,
                headers: { 'Content-Type' => 'application/json' })

    attachments = Saasi::InvoiceAttachment.for_invoice(33)
    expect(attachments.first).to be_a(Saasi::InvoiceAttachment)
    expect(attachments.first.name).to eq 'inv.pdf'
  end

  it 'uploads via the legacy base64 helper' do
    stub_request(:post, 'https://api.saasu.com/invoiceattachment?FileId=777').
      with(body: hash_including('Name' => 'inv.pdf', 'ItemIdAttachedTo' => 42)).
      to_return(status: 200, body: { InsertedEntityId: 5 }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = Saasi::InvoiceAttachment.upload(42, StringIO.new('PDF'), name: 'inv.pdf')
    expect(result['InsertedEntityId']).to eq 5
  end
end
