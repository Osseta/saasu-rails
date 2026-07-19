class Saasu::Invoice < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(InvoiceNumber PurchaseOrderNumber LastModifiedFromDate LastModifiedToDate TransactionType Tags TagSelection InvoiceFromDate InvoiceToDate InvoiceStatus PaymentStatus BillingContactId PageSize Page)

  def self.sales_stats_summary(params = {})
    Saasu::Client.request(:get, 'Invoices/SalesStatsSummary', params)
  end

  def email(email_address = nil)
    if email_address.present?
      url = ['Invoice', id, 'email'].join('/')
      params = { EmailTo: email_address }
    else
      url = ['Invoice', id, 'email-contact'].join('/')
      params = {}
    end

    Saasu::Client.request(:post, url, params)
  end

  # Returns the pdf file as raw binary data in a String object
  #
  # if there is problem getting the PDF you will get a runtime error
  #   e.g RuntimeError (Server did not return a valid response. URL: Invoice/9999/generate-pdf?FileId=9999. Response status: 400. Response body: Unable to perform the request.):
  #
  # this can happen if the tempate_id is invalid
  def generate_pdf(template_id = nil)
    if template_id.present?
      url = ['Invoice', id, 'generate-pdf'].join('/')
      params = { TemplateId: template_id }
    else
      url = ['Invoice', id, 'generate-pdf'].join('/')
      params = {}
    end

    Saasu::Client.request(:get, url, params)
  end
end
