require 'spec_helper'
require 'base64'
require 'stringio'
require 'tempfile'

describe Saasu::InvoiceAttachment do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  describe ".upload" do
    it 'posts the file content base64-encoded with the attachment fields' do
      stub_request(:post, 'https://api.saasu.com/invoiceattachment?FileId=777').
        with(body: {
          'Name' => 'inv.pdf',
          'ItemIdAttachedTo' => 42,
          'AttachmentData' => Base64.strict_encode64('PDFDATA'),
          'AllowExistingAttachmentToBeOverwritten' => true
        }).
        to_return(status: 200, body: { InsertedEntityId: 5 }.to_json, headers: {'Content-Type'=>'application/json'})

      result = Saasu::InvoiceAttachment.upload(42, StringIO.new('PDFDATA'), name: 'inv.pdf', overwrite: true)
      expect(result['InsertedEntityId']).to eq 5
    end

    it 'defaults the name to the file basename when given a path' do
      file = Tempfile.new(['statement', '.pdf'])
      file.write('DATA')
      file.close

      stub_request(:post, 'https://api.saasu.com/invoiceattachment?FileId=777').
        with(body: {
          'Name' => File.basename(file.path),
          'ItemIdAttachedTo' => 7,
          'AttachmentData' => Base64.strict_encode64('DATA'),
          'AllowExistingAttachmentToBeOverwritten' => false
        }).
        to_return(status: 200, body: { InsertedEntityId: 6 }.to_json, headers: {'Content-Type'=>'application/json'})

      expect(Saasu::InvoiceAttachment.upload(7, file.path)['InsertedEntityId']).to eq 6
    ensure
      file.unlink
    end

    it 'requires a name when the source has no filename' do
      expect { Saasu::InvoiceAttachment.upload(7, StringIO.new('DATA')) }.
        to raise_error(RuntimeError, /name is required/i)
    end
  end

  describe "#decoded_data" do
    it 'decodes the base64 AttachmentData' do
      attachment = Saasu::InvoiceAttachment.new('AttachmentData' => Base64.strict_encode64('hello'))
      expect(attachment.decoded_data).to eq 'hello'
    end

    it 'returns nil when there is no AttachmentData' do
      expect(Saasu::InvoiceAttachment.new({}).decoded_data).to be_nil
    end
  end
end
