require 'base64'

class Saasu::InvoiceAttachment < Saasu::Base
  allowed_methods :show, :destroy, :create

  def self.for_invoice(invoice_id)
    Saasu::Client.request(:get, "InvoiceAttachments/#{invoice_id}")["Attachments"].map do |record|
      new(record)
    end
  end

  # file: an IO (anything responding to #read) or a file path
  def self.upload(invoice_id, file, name: nil, description: nil, overwrite: false)
    if file.respond_to?(:read)
      data = file.read
    else
      data = File.binread(file)
      name ||= File.basename(file)
    end
    raise "Attachment name is required." if name.blank?

    payload = {
      'Name' => name,
      'Description' => description,
      'ItemIdAttachedTo' => invoice_id,
      'AttachmentData' => Base64.strict_encode64(data),
      'AllowExistingAttachmentToBeOverwritten' => overwrite,
    }.compact

    Saasu::Client.request(:post, resource_url, payload)
  end

  def decoded_data
    Base64.decode64(self['AttachmentData']) if self['AttachmentData'].present?
  end
end
