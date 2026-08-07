require 'spec_helper'

describe Saasi::Invoice do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    {
      'TransactionId' => 33, 'LastUpdatedId' => 'AAA=', 'InvoiceType' => 'Tax Invoice',
      'TransactionType' => 'S', 'Layout' => 'S', 'TransactionDate' => '2026-08-06',
      'TotalAmount' => 110.0, 'IsTaxInc' => true, 'Tags' => ['a'],
      'LineItems' => [{ 'Description' => 'Consulting', 'AccountId' => 1, 'TotalAmount' => 110.0,
                        'Attributes' => [{ 'AttributeId' => 7, 'Name' => 'Colour', 'Value' => 'Red' }] }],
      'Terms' => { 'Type' => 1, 'Interval' => 14, 'IntervalType' => 1 },
      'FutureApiField' => 'kept'
    }
  end

  it 'round-trips the wire hash losslessly' do
    expect(Saasi::Invoice.from_wire(wire).to_wire).to eq wire
  end

  it 'types BrandId and ForEntityTypeId (docs-only fields, absent from the .NET SDK)' do
    invoice = Saasi::Invoice.from_wire(wire.merge('BrandId' => 2, 'ForEntityTypeId' => 98))
    expect(invoice.brand_id).to eq 2
    expect(invoice.for_entity_type_id).to eq 98
    expect(invoice.to_wire['BrandId']).to eq 2
  end

  it 'passes PrintAs to generate-pdf when given' do
    stub_request(:get, 'https://api.saasu.com/Invoice/33/generate-pdf?FileId=777&PrintAs=98').
      to_return(status: 200, body: 'PDFBYTES')
    expect(Saasi::Invoice.from_wire(wire).generate_pdf(print_as: 98)).to eq 'PDFBYTES'
  end

  it 'types the interesting fields' do
    invoice = Saasi::Invoice.from_wire(wire)
    expect(invoice.transaction_date).to eq Date.new(2026, 8, 6)
    expect(invoice.total_amount).to eq BigDecimal('110')
    expect(invoice.line_items.first.item_attributes.first.name).to eq 'Colour'
    expect(invoice.id).to eq 33 # TransactionId fallback
  end

  it 'requires the .NET-required fields and validates enums' do
    invoice = Saasi::Invoice.new
    expect(invoice.valid?).to be false
    expect(invoice.errors.attribute_names).to include(:invoice_type, :transaction_type, :layout, :transaction_date, :line_items)

    invoice = Saasi::Invoice.from_wire(wire)
    invoice.transaction_type = 'X'
    expect(invoice.valid?).to be false
  end

  it 'excludes read-only fields from to_wire' do
    invoice = Saasi::Invoice.from_wire(wire.merge('PaymentStatus' => 'U', 'PaymentCount' => 1,
                                                  'Attachments' => [{ 'Id' => 1, 'Name' => 'a.pdf' }]))
    expect(invoice.payment_status).to eq 'U'
    expect(invoice.attachments.first.name).to eq 'a.pdf'
    expect(invoice.to_wire).to eq wire
  end

  it 'finds via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/invoice/33?FileId=777').
      to_return(status: 200, body: wire.to_json, headers: { 'Content-Type' => 'application/json' })
    expect(Saasi::Invoice.find(33).invoice_type).to eq 'Tax Invoice'
  end

  it 'refuses a quick payment on a persisted invoice' do
    invoice = Saasi::Invoice.from_wire(wire)
    invoice.quick_payment = { date_paid: '2026-08-06', banked_to_account_id: 1, amount: 10.0 }
    expect { invoice.save }.to raise_error(RuntimeError, /POST only/)
  end

  it 'no longer reports persisted after delete (TransactionId cleared too)' do
    stub_request(:delete, 'https://api.saasu.com/invoice/33?FileId=777').
      to_return(status: 200, body: { StatusMessage: 'Ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

    invoice = Saasi::Invoice.from_wire(wire)
    expect(invoice.delete).to be true
    expect(invoice).not_to be_persisted
  end

  it 'delegates the non-CRUD invoice helpers to the legacy class' do
    stub_request(:get, 'https://api.saasu.com/Invoices/SalesStatsSummary?FileId=777').
      to_return(status: 200, body: { Sales: 1 }.to_json, headers: { 'Content-Type' => 'application/json' })
    expect(Saasi::Invoice.sales_stats_summary['Sales']).to eq 1

    stub_request(:post, 'https://api.saasu.com/Invoice/33/email-contact?FileId=777').
      to_return(status: 200, body: { StatusMessage: 'Ok' }.to_json, headers: { 'Content-Type' => 'application/json' })
    expect(Saasi::Invoice.from_wire(wire).email['StatusMessage']).to eq 'Ok'

    stub_request(:get, 'https://api.saasu.com/Invoice/33/generate-pdf?FileId=777').
      to_return(status: 200, body: 'PDFBYTES')
    expect(Saasi::Invoice.from_wire(wire).generate_pdf).to eq 'PDFBYTES'
  end
end
