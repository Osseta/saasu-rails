require 'spec_helper'

describe "P1 gap-analysis fixes" do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  describe "R1: HTTP status handling" do
    it 'treats 201 as success and returns the body' do
      stub_request(:post, 'https://api.saasu.com/p1test?FileId=777').
        to_return(status: 201, body: { Id: 9 }.to_json, headers: {'Content-Type'=>'application/json'})

      expect(Saasu::Client.request(:post, 'p1test', { Name: 'x' })).to eq({ "Id" => 9 })
    end

    it 'treats 204 as success and returns nil' do
      stub_request(:delete, 'https://api.saasu.com/p1test/9?FileId=777').
        to_return(status: 204, body: '')

      expect(Saasu::Client.request(:delete, 'p1test/9')).to be_blank
    end

    it 'raises Saasu::NotFoundError on 404 with the legacy message' do
      stub_request(:get, 'https://api.saasu.com/p1test/1?FileId=777').
        to_return(status: 404, body: '')

      expect { Saasu::Client.request(:get, 'p1test/1') }.
        to raise_error(Saasu::NotFoundError, "Resource not found.")
    end

    it 'raises Saasu::Error carrying status and body on other failures' do
      stub_request(:get, 'https://api.saasu.com/p1test/1?FileId=777').
        to_return(status: 500, body: { Errors: ['boom'] }.to_json, headers: {'Content-Type'=>'application/json'})

      expect { Saasu::Client.request(:get, 'p1test/1') }.to raise_error(Saasu::Error) do |error|
        expect(error.status).to eq 500
        expect(error.body).to eq({ "Errors" => ["boom"] })
      end
    end

    it 'remains rescuable as RuntimeError for backwards compatibility' do
      expect(Saasu::Error.ancestors).to include(RuntimeError)
    end
  end

  describe "R2: envelope unwrapping by collection key" do
    it 'picks the collection by key even when it is not the first envelope entry' do
      stub_request(:get, 'https://api.saasu.com/p1tests?FileId=777').
        to_return(status: 200,
                  body: { StatusMessage: 'Ok', P1Tests: [{ Id: 1 }, { Id: 2 }], TotalRecords: 2 }.to_json,
                  headers: {'Content-Type'=>'application/json'})

      records = Saasu::P1Test.all
      expect(records.map(&:id)).to eq [1, 2]
    end

    it 'honours a per-class collection_key override' do
      stub_request(:get, 'https://api.saasu.com/p1renamedtests?FileId=777').
        to_return(status: 200,
                  body: { StatusMessage: 'Ok', Widgets: [{ Id: 5 }] }.to_json,
                  headers: {'Content-Type'=>'application/json'})

      expect(Saasu::P1RenamedTest.all.first.id).to eq 5
    end

    it 'uses the inserted entity id from the insert envelope, not the first value' do
      stub_request(:post, 'https://api.saasu.com/p1test?FileId=777').
        to_return(status: 200,
                  body: { StatusMessage: 'ok', InsertedEntityId: 555 }.to_json,
                  headers: {'Content-Type'=>'application/json'})
      stub_request(:get, 'https://api.saasu.com/p1test/555?FileId=777').
        to_return(status: 200, body: { Id: 555 }.to_json, headers: {'Content-Type'=>'application/json'})

      expect(Saasu::P1Test.create(Name: 'x').id).to eq 555
    end
  end

  describe "R3: envelope metadata" do
    it 'exposes non-collection envelope fields as metadata on list results' do
      stub_request(:get, 'https://api.saasu.com/p1tests?FileId=777').
        to_return(status: 200,
                  body: { P1Tests: [{ Id: 1 }], TotalRecords: 42, CurrentPage: 3 }.to_json,
                  headers: {'Content-Type'=>'application/json'})

      records = Saasu::P1Test.all
      expect(records).to be_an(Array)
      expect(records.metadata).to eq({ "TotalRecords" => 42, "CurrentPage" => 3 })
    end
  end

  describe "R4/D3: find with a blank response" do
    it 'returns nil instead of crashing' do
      stub_request(:get, 'https://api.saasu.com/p1test/1?FileId=777').
        to_return(status: 200, body: '')

      expect(Saasu::P1Test.find(1)).to be_nil
    end
  end

  describe "R4/D4: classes missing allowed_methods or filter_by" do
    it 'raises the intended unsupported-method message, not NoMethodError' do
      expect { Saasu::P1Bare.all }.
        to raise_error(RuntimeError, /not currently supported by Saasu API/)
    end

    it 'raises the intended unsupported-filter message when no filters are declared' do
      expect { Saasu::P1NoFilters.where(Anything: 1) }.
        to raise_error(RuntimeError, /Filter not supported by Saasu API: Anything/)
    end
  end

  describe "R4/D5: plural attribute accessors" do
    it 'reads plural attributes via method_missing' do
      record = Saasu::P1Test.new('Tags' => ['a', 'b'])
      expect(record.tags).to eq ['a', 'b']
    end

    it 'writes plural attributes via method_missing without singularizing or flattening' do
      record = Saasu::P1Test.new('Tags' => [])
      record.tags = ['a', 'b']
      expect(record['Tags']).to eq ['a', 'b']
      expect(record['Tag']).to be_nil
    end
  end

  describe "R4/D6: Item filters" do
    it 'accepts Page and SearchText' do
      stub_request(:get, 'https://api.saasu.com/items?FileId=777&Page=1&SearchMethod=Contains&SearchText=abc').
        to_return(status: 200, body: { Items: [] }.to_json, headers: {'Content-Type'=>'application/json'})

      expect { Saasu::Item.where(Page: 1, SearchMethod: 'Contains', SearchText: 'abc') }.
        not_to raise_error
    end
  end

  describe "R1: instance delete with a blank body" do
    it 'returns false instead of crashing' do
      record = Saasu::P1Test.new('Id' => 9)
      stub_request(:delete, 'https://api.saasu.com/p1test/9?FileId=777').
        to_return(status: 204, body: '')

      expect(record.delete).to be false
    end
  end
end

class Saasu::P1Test < Saasu::Base
  allowed_methods :show, :index, :update, :create, :destroy
  filter_by %W(Id Name)
end

class Saasu::P1RenamedTest < Saasu::Base
  allowed_methods :index
  collection_key 'Widgets'
end

class Saasu::P1Bare < Saasu::Base
end

class Saasu::P1NoFilters < Saasu::Base
  allowed_methods :index
end
