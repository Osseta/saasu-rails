class Saasu::Invoice < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(InvoiceNumber PurchaseOrderNumber LastModifiedFromDate LastModifiedToDate TransactionType Tags TagSelection InvoiceFromDate InvoiceToDate InvoiceStatus PaymentStatus BillingContactId PageSize Page)

  def self.sales_stats_summary(params = {})
    Saasu::Client.request(:get, 'Invoices/SalesStatsSummary', params)
  end

  # Record a payment as part of creating this invoice (one round-trip instead
  # of a separate Saasu::Payment). The API accepts QuickPayment on POST only
  # and never returns it on GET, so this is a write instruction, not an attribute.
  def add_quick_payment(date_paid:, banked_to_account_id:, amount:, date_cleared: nil, reference: nil, summary: nil)
    raise "QuickPayment can only be added when creating an invoice (the API accepts it on POST only)" if id.present?
    raise ArgumentError, "amount must have at most 2 decimal places" if amount != amount.round(2)

    self['QuickPayment'] = {
      'DatePaid'          => format_date(date_paid),
      'DateCleared'       => format_date(date_cleared),
      'BankedToAccountId' => banked_to_account_id,
      'Amount'            => amount,
      'Reference'         => reference,
      'Summary'           => summary,
    }.compact
    self
  end

  # Instruct the API to email this invoice to the billing contact as part of
  # the next create/update. With no arguments the API uses its default template.
  # Not returned on GET, so this is a write instruction, not an attribute.
  def email_on_save(subject: nil, body: nil, from: nil, to: nil, cc: nil, bcc: nil)
    self['SendEmailToContact'] = true

    message = {
      'From'    => from,
      'To'      => to,
      'Subject' => subject,
      'Body'    => body,
      'Cc'      => cc,
      'Bcc'     => bcc,
    }.compact
    self['EmailMessage'] = message if message.present?
    self
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
  # this can happen if the template_id is invalid
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

  private

  def format_date(value)
    value.respond_to?(:strftime) ? value.strftime('%Y-%m-%d') : value
  end
end
