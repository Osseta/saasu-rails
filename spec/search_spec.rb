require 'spec_helper'

describe Saasu::Search do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    mock_api_requests
  end

  describe ".search" do
    it 'uses the default scope when no scope specified' do
      query = Saasu::Search.new('Customer')
      expect(query.perform).to eq({ contacts: 8, invoices: 10, items: 15 })
      expect(a_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=false&Keywords=Customer&Scope=All"))
        .to have_been_made
    end

    it 'uses the default scope when no scope specified and specifies a transaction type' do
      query = Saasu::Search.new('Customer', transaction_type: 'Sale')
      expect(query.perform).to eq({ contacts: 9, invoices: 8, items: 7 })
      expect(a_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=false&Keywords=Customer&Scope=All&TransactionType=Transactions.Sale"))
        .to have_been_made
    end

    it 'passes paging params' do
      stub_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=false&Keywords=Customer&Scope=All&Page=2&PageSize=50").
        to_return(status: 200, body: search_results.to_json, headers: {'Content-Type'=>'application/json'})

      Saasu::Search.new('Customer', page: 2, page_size: 50).perform

      expect(a_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=false&Keywords=Customer&Scope=All&Page=2&PageSize=50"))
        .to have_been_made
    end

    it 'allows enabling search term highlights' do
      stub_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=true&Keywords=Customer&Scope=All").
        to_return(status: 200, body: search_results.to_json, headers: {'Content-Type'=>'application/json'})

      Saasu::Search.new('Customer', include_search_term_highlights: true).perform

      expect(a_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=true&Keywords=Customer&Scope=All"))
        .to have_been_made
    end
  end

  describe "result accessors" do
    before do
      stub_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=false&Keywords=Customer&Scope=All").
        to_return(status: 200, body: {
          "Contacts" => [{ "Id" => 1, "GivenName" => "Jack" }],
          "Transactions" => [{ "TransactionId" => 2, "InvoiceNumber" => "INV-2" }],
          "InventoryItems" => [{ "Id" => 3, "Code" => "BOOK" }],
          "TotalContactsFound" => 1,
          "TotalTransactionsFound" => 1,
          "TotalInventoryItemsFound" => 1
        }.to_json, headers: {'Content-Type'=>'application/json'})
    end

    it 'maps contacts to Saasu::Contact objects' do
      contacts = Saasu::Search.new('Customer').contacts
      expect(contacts.first).to be_a(Saasu::Contact)
      expect(contacts.first.given_name).to eq 'Jack'
    end

    it 'maps transactions to Saasu::Invoice objects, using TransactionId as the id' do
      invoices = Saasu::Search.new('Customer').invoices
      expect(invoices.first).to be_a(Saasu::Invoice)
      expect(invoices.first.id).to eq 2
    end

    it 'maps inventory items to Saasu::Item objects' do
      items = Saasu::Search.new('Customer').items
      expect(items.first).to be_a(Saasu::Item)
      expect(items.first['Code']).to eq 'BOOK'
    end
  end

  private
  def mock_api_requests
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      with(body: { grant_type: 'password', scope: 'full', username: 'user@saasu.com', password: 'password' },
      headers: {'Content-Type'=>'application/json', 'X-Api-Version'=>'1.0'}).
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=false&Keywords=Customer&Scope=All").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Authorization'=>'Bearer 12345', 'X-Api-Version'=>'1.0'}).
      to_return(:status => 200, body: search_results.to_json, :headers => {'Content-Type'=>'application/json'})

    stub_request(:get, "https://api.saasu.com/search?FileId=777&IncludeSearchTermHighlights=false&Keywords=Customer&Scope=All&TransactionType=Transactions.Sale").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Authorization'=>'Bearer 12345', 'X-Api-Version'=>'1.0'}).
      to_return(:status => 200, body: search_results_with_transaction_type.to_json, :headers => {'Content-Type'=>'application/json'})
  end

  def search_results
    {
      "TotalContactsFound" => 8,
      "TotalTransactionsFound" => 10,
      "TotalInventoryItemsFound" => 15
    }
  end

  def search_results_with_transaction_type
    {
      "TotalContactsFound" => 9,
      "TotalTransactionsFound" => 8,
      "TotalInventoryItemsFound" => 7
    }
  end
end
