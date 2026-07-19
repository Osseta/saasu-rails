class Saasu::InvoiceAttachment < Saasu::Base
  allowed_methods :show, :destroy, :create

  def self.for_invoice(invoice_id)
    Saasu::Client.request(:get, "InvoiceAttachments/#{invoice_id}")["Attachments"].map do |record|
      new(record)
    end
  end
end
