# spec/saasi/base_spec.rb
require 'spec_helper'

class Saasi::TestPart < Saasi::Base
  attribute :code, :string
  attribute :qty,  :integer
end

class Saasi::TestMachine < Saasi::Base
  attribute :id, :integer
  has_many :parts,    Saasi::TestPart
  has_one  :main_part, Saasi::TestPart, wire_key: 'PrimaryPart'
  attribute :serial, :string
  read_only :serial
end

class Saasi::TestWidget < Saasi::Base
  attribute :id,          :integer
  attribute :given_name,  :string
  attribute :born_on,     :date
  attribute :updated_utc, :datetime
  attribute :price,       :decimal
  attribute :is_active,   :boolean
  attribute :tags,        :string_array
  attribute :cc_address,  :string, wire_key: 'CCAddress'
end

describe Saasi::Base do
  describe 'wire mapping and coercion' do
    it 'builds from a wire hash, coercing types' do
      widget = Saasi::TestWidget.from_wire(
        'Id' => 5, 'GivenName' => 'Jack', 'BornOn' => '2020-01-31',
        'UpdatedUtc' => '2026-08-06T01:02:03Z', 'Price' => 10.5,
        'IsActive' => false, 'Tags' => ['a', 'b'], 'CCAddress' => 'x@y.z'
      )

      expect(widget.given_name).to eq 'Jack'
      expect(widget.born_on).to eq Date.new(2020, 1, 31)
      expect(widget.updated_utc).to be_a(Time)
      expect(widget.price).to eq BigDecimal('10.5')
      expect(widget.is_active).to be false
      expect(widget.tags).to eq ['a', 'b']
      expect(widget.cc_address).to eq 'x@y.z'
    end

    it 'accepts snake_case attributes at construction' do
      expect(Saasi::TestWidget.new(given_name: 'Jill').given_name).to eq 'Jill'
    end

    it 'raises on undeclared attribute assignment' do
      expect { Saasi::TestWidget.new(given_nane: 'typo') }.to raise_error(ActiveModel::UnknownAttributeError)
    end
  end

  describe 'extra (undeclared wire keys)' do
    it 'preserves unknown keys through a round trip' do
      wire = { 'Id' => 5, 'BrandNewApiField' => { 'Nested' => 1 } }
      widget = Saasi::TestWidget.from_wire(wire)
      expect(widget.extra).to eq({ 'BrandNewApiField' => { 'Nested' => 1 } })
      expect(widget.to_wire).to eq wire
    end
  end

  describe '#to_wire' do
    it 'satisfies the round-trip law for canonical wire values' do
      wire = {
        'Id' => 5, 'GivenName' => 'Jack', 'BornOn' => '2020-01-31',
        'UpdatedUtc' => '2026-08-06T01:02:03Z', 'Price' => 10.5,
        'IsActive' => false, 'Tags' => ['a'], 'CCAddress' => 'x@y.z',
        'Unknown' => 'kept'
      }
      expect(Saasi::TestWidget.from_wire(wire).to_wire).to eq wire
    end

    it 'omits nil attributes (including unset string_array) but emits false' do
      widget = Saasi::TestWidget.new(is_active: false)
      expect(widget.to_wire).to eq({ 'IsActive' => false })
      expect(Saasi::TestWidget.new.to_wire).to eq({})
    end

    it 'serialises Date, Time and BigDecimal to wire form' do
      widget = Saasi::TestWidget.new(
        born_on: Date.new(2026, 8, 6),
        updated_utc: Time.utc(2026, 8, 6, 1, 2, 3),
        price: BigDecimal('99.95')
      )
      expect(widget.to_wire).to eq(
        'BornOn' => '2026-08-06',
        'UpdatedUtc' => '2026-08-06T01:02:03Z',
        'Price' => 99.95
      )
    end
  end

  describe 'nested models' do
    it 'coerces hashes into typed nested models on read and write' do
      machine = Saasi::TestMachine.from_wire(
        'Id' => 1,
        'Parts' => [{ 'Code' => 'A', 'Qty' => 2 }],
        'PrimaryPart' => { 'Code' => 'B', 'Qty' => 1 }
      )
      expect(machine.parts.first).to be_a(Saasi::TestPart)
      expect(machine.parts.first.qty).to eq 2
      expect(machine.main_part.code).to eq 'B'

      machine.parts = [{ code: 'C', qty: 9 }]
      expect(machine.parts.first).to be_a(Saasi::TestPart)
      expect(machine.parts.first.code).to eq 'C'
    end

    it 'serialises nested models and omits empty collections' do
      machine = Saasi::TestMachine.new(id: 1)
      expect(machine.to_wire).to eq({ 'Id' => 1 })

      machine.main_part = Saasi::TestPart.new(code: 'B')
      expect(machine.to_wire).to eq({ 'Id' => 1, 'PrimaryPart' => { 'Code' => 'B' } })
    end

    it 'round-trips nested wire hashes losslessly' do
      wire = { 'Id' => 1, 'Parts' => [{ 'Code' => 'A', 'Qty' => 2, 'Surprise' => true }] }
      expect(Saasi::TestMachine.from_wire(wire).to_wire).to eq wire
    end

    it 'excludes read_only names from to_wire but still reads them' do
      machine = Saasi::TestMachine.from_wire('Id' => 1, 'Serial' => 'XYZ')
      expect(machine.serial).to eq 'XYZ'
      expect(machine.to_wire).to eq({ 'Id' => 1 })
    end

    it 'cascades validation into nested models' do
      part_class = Class.new(Saasi::Base) do
        attribute :code, :string
        validates :code, presence: true
      end
      machine_class = Class.new(Saasi::Base) do
        attribute :id, :integer
        has_many :parts, part_class
      end

      machine = machine_class.new(parts: [{}])
      expect(machine.valid?).to be false
      expect(machine.errors[:parts]).to be_present

      machine.parts = [{ code: 'A' }]
      expect(machine.valid?).to be true
    end
  end
end

class Saasu::WidgetLegacy < Saasu::Base   # legacy side of the fixture pair
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(GivenName Page PageSize)
  def self.resource_url(id = nil) = ['widgetlegacy', id].compact.join('/')
end

class Saasi::Widget < Saasi::Base
  wraps Saasu::WidgetLegacy
  attribute :id,         :integer
  attribute :given_name, :string
  validates :given_name, presence: true
end

describe 'CRUD delegation' do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'finds and wraps a record' do
    stub_request(:get, 'https://api.saasu.com/widgetlegacy/5?FileId=777').
      to_return(status: 200, body: { Id: 5, GivenName: 'Jack', Mystery: 'kept' }.to_json,
                headers: { 'Content-Type' => 'application/json' })

    widget = Saasi::Widget.find(5)
    expect(widget.given_name).to eq 'Jack'
    expect(widget.extra['Mystery']).to eq 'kept'
    expect(widget).to be_persisted
  end

  it 'lists into a Saasi::Collection with metadata' do
    stub_request(:get, 'https://api.saasu.com/widgetlegacies?FileId=777').
      to_return(status: 200, body: { WidgetLegacys: [{ Id: 1 }], Total: 7 }.to_json,
                headers: { 'Content-Type' => 'application/json' })

    widgets = Saasi::Widget.all
    expect(widgets.first).to be_a(Saasi::Widget)
    expect(widgets.metadata).to eq({ 'Total' => 7 })
  end

  it 'creates via the legacy class and refreshes from the API' do
    stub_request(:post, 'https://api.saasu.com/widgetlegacy?FileId=777').
      with(body: { GivenName: 'Jack' }).
      to_return(status: 200, body: { InsertedEntityId: 9 }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.saasu.com/widgetlegacy/9?FileId=777').
      to_return(status: 200, body: { Id: 9, GivenName: 'Jack' }.to_json, headers: { 'Content-Type' => 'application/json' })

    widget = Saasi::Widget.create(given_name: 'Jack')
    expect(widget.id).to eq 9
  end

  it 'raises ValidationError before any HTTP when invalid' do
    expect { Saasi::Widget.create({}) }.to raise_error(Saasi::ValidationError) do |error|
      expect(error.errors[:given_name]).to be_present # key-based: locale-independent
    end
    expect(a_request(:post, 'https://api.saasu.com/widgetlegacy?FileId=777')).not_to have_been_made
  end

  it 'clears attributes and extras absent from the post-save response' do
    stub_request(:post, 'https://api.saasu.com/widgetlegacy?FileId=777').
      to_return(status: 200, body: { InsertedEntityId: 9 }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.saasu.com/widgetlegacy/9?FileId=777').
      to_return(status: 200, body: { Id: 9 }.to_json, headers: { 'Content-Type' => 'application/json' })

    widget = Saasi::Widget.new(given_name: 'Jack')
    widget.save
    expect(widget.id).to eq 9
    expect(widget.given_name).to be_nil # not in the GET response — must not go stale
  end

  it 'deletes via the legacy class and clears the id' do
    stub_request(:delete, 'https://api.saasu.com/widgetlegacy/5?FileId=777').
      to_return(status: 200, body: { StatusMessage: 'Ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

    widget = Saasi::Widget.from_wire('Id' => 5)
    expect(widget.delete).to be true
    expect(widget.id).to be_nil
  end
end
