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
