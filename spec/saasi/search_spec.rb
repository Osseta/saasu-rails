require 'spec_helper'

describe Saasi::Search do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    # Fixture mirrors the .NET search DTO shapes (ContactSearchResponse /
    # TransactionSearchResponse / InventoryItemSearchResponse): search results use
    # 'Id' and search-specific display fields, not the full resource shape
    stub_request(:get, %r{https://api.saasu.com/search}).
      to_return(status: 200, body: {
        'Contacts' => [{ 'Id' => 1, 'GivenName' => 'Jack', 'EntityType' => 'Contact' }],
        'Transactions' => [{ 'Id' => 2, 'InvoiceNumber' => 'INV-2', 'Type' => 'S', 'Date' => '2026-08-01' }],
        'InventoryItems' => [{ 'Id' => 3, 'Code' => 'BOOK', 'SellingPrice' => 25.5 }],
        'TotalContactsFound' => 1, 'TotalTransactionsFound' => 1, 'TotalInventoryItemsFound' => 1
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'returns Saasi-typed results, preserving search-only fields in extra' do
    search = Saasi::Search.new('Book')
    expect(search.contacts.first).to be_a(Saasi::Contact)
    expect(search.contacts.first.extra['EntityType']).to eq 'Contact'
    expect(search.invoices.first).to be_a(Saasi::Invoice)
    expect(search.invoices.first.id).to eq 2
    expect(search.invoices.first.extra['Type']).to eq 'S' # search DTO field, not an Invoice attribute
    expect(search.items.first.code).to eq 'BOOK'
    expect(search.items.first.selling_price).to eq BigDecimal('25.5')
  end
end
