require 'spec_helper'

describe Saasu::Base do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    mock_api_requests
  end

  describe "#all" do
    it 'returns records' do
      expect(Saasu::Test.all.count).to eq 1
    end
  end

  describe "#find" do
    it 'returns records' do
      expect(Saasu::Test.find(1)['id']).to eq 76543
      expect(Saasu::Test.find(2)['id']).to eq 98765
    end
  end

  describe "#where" do
    it 'validates filters' do
      expect{ Saasu::Test.where({ Name: 1 }) }.to raise_error
      expect{ Saasu::Test.where({ FirstName: 1 }) }.not_to raise_error
    end

    context 'method not implemented' do
      it 'raises an error' do
        expect{ Saasu::TestTwo.where({ Id: 1 }) }.to raise_error
      end
    end

    it 'returns records' do
      expect(Saasu::Test.where({ FirstName: 'Tester' }).first['id']).to eq 112233
    end
  end

  describe "#save" do
    it 'returns records' do
      record = Saasu::Test.new
      record['Name'] = 'Tester'
      expect(record.save).to be true
      expect(record.id).to eq 123
      expect(record.surname).to eq 'Spade'

      expect(a_request(:post, "https://api.saasu.com/test?FileId=777")).to have_been_made
    end
  end

  describe "#create" do
    it 'returns records' do
      record = Saasu::Test.create(GivenName: 'Jack')
      expect(record.id).to eq 765
      expect(record.surname).to eq 'Sparrow'

      expect(a_request(:post, "https://api.saasu.com/test?FileId=777")).to have_been_made
    end
  end

  describe "#delete" do
    it 'returns records' do
      record = Saasu::Test.create(GivenName: 'Jack')
      record.delete
      expect(record.id).to be_nil

      expect(a_request(:delete, "https://api.saasu.com/test/765?FileId=777")).to have_been_made
    end
  end

  describe "#validate_method_is_implemented_in_saasu_api" do
    it 'raises an exception when a method is not implemented in Saasu API' do
      expect { Saasu::Test.create({}) }.to raise_error
    end

    it 'raises the intended unsupported-method message when allowed_methods was never declared' do
      expect { Saasu::TestBare.all }.
        to raise_error(RuntimeError, /not currently supported by Saasu API/)
    end
  end

  describe ".validate_filters" do
    it 'raises the intended unsupported-filter message when no filters are declared' do
      expect { Saasu::TestNoFilters.where(Anything: 1) }.
        to raise_error(RuntimeError, /Filter not supported by Saasu API: Anything/)
    end
  end

  describe "envelope unwrapping" do
    it 'picks the collection by key even when it is not the first envelope entry' do
      stub_request(:get, 'https://api.saasu.com/tests?FileId=777').
        to_return(status: 200,
                  body: { StatusMessage: 'Ok', Tests: [{ Id: 1 }, { Id: 2 }], TotalRecords: 2 }.to_json,
                  headers: {'Content-Type'=>'application/json'})

      expect(Saasu::Test.all.map(&:id)).to eq [1, 2]
    end

    it 'honours a per-class collection_key override' do
      stub_request(:get, 'https://api.saasu.com/testrenamedcollections?FileId=777').
        to_return(status: 200,
                  body: { StatusMessage: 'Ok', Widgets: [{ Id: 5 }] }.to_json,
                  headers: {'Content-Type'=>'application/json'})

      expect(Saasu::TestRenamedCollection.all.first.id).to eq 5
    end

    it 'exposes non-collection envelope fields as metadata on list results' do
      stub_request(:get, 'https://api.saasu.com/tests?FileId=777').
        to_return(status: 200,
                  body: { Tests: [{ Id: 1 }], TotalRecords: 42, CurrentPage: 3 }.to_json,
                  headers: {'Content-Type'=>'application/json'})

      records = Saasu::Test.all
      expect(records).to be_an(Array)
      expect(records.metadata).to eq({ "TotalRecords" => 42, "CurrentPage" => 3 })
    end

    it 'uses the inserted entity id from the insert envelope, not the first value' do
      stub_request(:post, 'https://api.saasu.com/test?FileId=777').
        with(body: { Name: 'InsertedIdTest' }).
        to_return(status: 200,
                  body: { StatusMessage: 'ok', InsertedEntityId: 555 }.to_json,
                  headers: {'Content-Type'=>'application/json'})
      stub_request(:get, 'https://api.saasu.com/test/555?FileId=777').
        to_return(status: 200, body: { Id: 555 }.to_json, headers: {'Content-Type'=>'application/json'})

      expect(Saasu::Test.create(Name: 'InsertedIdTest').id).to eq 555
    end
  end

  describe "#find with a blank response" do
    it 'returns nil instead of crashing' do
      stub_request(:get, 'https://api.saasu.com/test/55?FileId=777').
        to_return(status: 200, body: '')

      expect(Saasu::Test.find(55)).to be_nil
    end
  end

  describe "plural attribute accessors" do
    it 'reads plural attributes via method_missing' do
      record = Saasu::Test.new('Tags' => ['a', 'b'])
      expect(record.tags).to eq ['a', 'b']
    end

    it 'writes plural attributes via method_missing without singularizing or flattening' do
      record = Saasu::Test.new('Tags' => [])
      record.tags = ['a', 'b']
      expect(record['Tags']).to eq ['a', 'b']
      expect(record['Tag']).to be_nil
    end
  end

  describe "#delete with a blank body" do
    it 'returns false instead of crashing' do
      record = Saasu::Test.new('Id' => 9)
      stub_request(:delete, 'https://api.saasu.com/test/9?FileId=777').
        to_return(status: 204, body: '')

      expect(record.delete).to be false
    end
  end

  private
  def mock_api_requests
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      with(body: { grant_type: 'password', scope: 'full', username: 'user@saasu.com', password: 'password' },
      headers: {'Content-Type'=>'application/json', 'X-Api-Version'=>'1.0'}).
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:post, 'https://api.saasu.com/test?FileId=777').
      with(body: { Name: 'Tester' },
      headers: {'Content-Type'=>'application/json', 'X-Api-Version'=>'1.0'}).
      to_return(status: 200, body: { Id: 123 }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:post, 'https://api.saasu.com/test?FileId=777').
      with(body: { GivenName: 'Jack' },
      headers: {'Content-Type'=>'application/json', 'X-Api-Version'=>'1.0'}).
      to_return(status: 200, body: { Id: 765 }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, "https://api.saasu.com/test/123?FileId=777").
      with(headers: {'Authorization' => 'Bearer 12345', 'X-Api-Version'=>'1.0'}).
      to_return(status: 200, body: { "Id" => 123, Surname: 'Spade'}.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, "https://api.saasu.com/test/765?FileId=777").
      with(headers: {'Authorization' => 'Bearer 12345', 'X-Api-Version'=>'1.0'}).
      to_return(status: 200, body: { "Id" => 765, Surname: 'Sparrow'}.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:delete, "https://api.saasu.com/test/765?FileId=777").
      with(headers: {'Authorization' => 'Bearer 12345', 'X-Api-Version'=>'1.0'}).
      to_return(status: 200, body: { "StatusMessage" => "Ok" }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, 'https://api.saasu.com/tests?FileId=777').
      with(headers: {'X-Api-Version'=>'1.0', 'Authorization'=>'Bearer 12345'}).
      to_return(status: 200, body: { contacts: [{id: 1234, first_name: 'John'}] }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, 'https://api.saasu.com/test/1?FileId=777').
      with(headers: {'X-Api-Version'=>'1.0', 'Authorization'=>'Bearer 12345'}).
      to_return(status: 200, body: { id: 76543 }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, 'https://api.saasu.com/test/2?FileId=777').
      with(headers: {'X-Api-Version'=>'1.0', 'Authorization'=>'Bearer 12345'}).
      to_return(status: 200, body: { id: 98765 }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, 'https://api.saasu.com/tests?FileId=777&FirstName=1').
      with(headers: {'X-Api-Version'=>'1.0', 'Authorization'=>'Bearer 12345'}).
      to_return(status: 200, body: { "Values" => [ ] }.to_json, headers: {'Content-Type'=>'application/json'})

    stub_request(:get, 'https://api.saasu.com/tests?FileId=777&FirstName=Tester').
      with(headers: {'X-Api-Version'=>'1.0', 'Authorization'=>'Bearer 12345'}).
      to_return(status: 200, body: { contacts: [{id: 112233}] }.to_json, headers: {'Content-Type'=>'application/json'})
  end
end

class Saasu::Test < Saasu::Base
  allowed_methods :show, :index, :update, :create, :destroy
  filter_by %W(Id FirstName)
end

class Saasu::TestTwo < Saasu::Base
  allowed_methods :show
end

class Saasu::TestRenamedCollection < Saasu::Base
  allowed_methods :index
  collection_key 'Widgets'
end

class Saasu::TestBare < Saasu::Base
end

class Saasu::TestNoFilters < Saasu::Base
  allowed_methods :index
end
