require 'spec_helper'

describe Saasu::Constants do
  it 'exposes the wire vocabularies from the official SDK' do
    expect(Saasu::Constants::INVOICE_STATUSES[:quote]).to eq 'Q'
    expect(Saasu::Constants::PAYMENT_STATUSES[:unpaid]).to eq 'U'
    expect(Saasu::Constants::INVOICE_TRANSACTION_TYPES[:sale]).to eq 'S'
    expect(Saasu::Constants::PAYMENT_TRANSACTION_TYPES[:purchase_payment]).to eq 'PP'
    expect(Saasu::Constants::TAG_SELECTIONS).to include('requireAny')
    expect(Saasu::Constants::ACCOUNT_TYPES).to include('Cost of Sales')
    expect(Saasu::Constants::ITEM_TYPES[:combo]).to eq 'C'
    expect(Saasu::Constants::SEARCH_METHODS).to include('StartsWith')
    expect(Saasu::Constants::ACTIVITY_STATUSES).to include('overdue')
    expect(Saasu::Constants::ATTACHED_TO_TYPES).to include('Employee')
    expect(Saasu::Constants::DELETED_ENTITY_TYPES).to include('SalePayment')
    expect(Saasu::Constants::SEARCH_SCOPES).to include('InventoryItems')
    expect(Saasu::Constants::OAUTH_SCOPES).to include('full')
    expect(Saasu::Constants::INVOICE_LAYOUTS[:service]).to eq 'S'
    expect(Saasu::Constants::INVOICE_TYPES).to include('Credit Note')
    expect(Saasu::Constants::TAX_CODES[:sale_incl_gst]).to eq 'G1'
    expect(Saasu::Constants::AUTO_NUMBER).to eq '<auto number>'
  end
end
