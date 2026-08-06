# spec/saasi/base_spec.rb
require 'spec_helper'

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
end
