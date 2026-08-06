module Saasi
  class InvoiceAttachment < Saasi::Base
    wraps Saasu::InvoiceAttachment

    attribute :id,                   :integer
    attribute :name,                 :string
    attribute :description,          :string
    attribute :item_id_attached_to,  :integer
    attribute :size,                 :integer
    attribute :attachment_data,      :string  # base64 on the wire
    attribute :allow_existing_attachment_to_be_overwritten, :boolean

    read_only :size

    def self.for_invoice(invoice_id)
      Collection.new(Saasu::InvoiceAttachment.for_invoice(invoice_id).map { |a| from_wire(a.attributes) })
    end

    # Delegates to the legacy base64 upload helper; returns the insert envelope hash
    def self.upload(invoice_id, file, name: nil, description: nil, overwrite: false)
      Saasu::InvoiceAttachment.upload(invoice_id, file, name: name, description: description, overwrite: overwrite)
    end

    def decoded_data
      Base64.decode64(attachment_data) if attachment_data.present?
    end
  end
end
