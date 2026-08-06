# Saasi Typed Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new top-level `Saasi` namespace of ActiveModel-typed models for every Saasu resource, wrapping the existing `Saasu::` classes so existing applications work unchanged.

**Architecture:** `Saasi::Base` (ActiveModel::Model + ActiveModel::Attributes) adds a wire-key map (snake_case attr ↔ PascalCase API key), `has_one`/`has_many` nested value objects, and an `extra` hash that preserves undeclared wire keys losslessly. All HTTP goes through the legacy `Saasu::` classes — Saasi never talks to `Saasu::Client` directly.

**Tech Stack:** Ruby 3.2, ActiveModel (>= 6.0), RSpec + WebMock (existing suite conventions).

**Spec:** `docs/superpowers/specs/2026-08-06-saasi-typed-models-design.md` — read it first.

## Global Constraints

- Branch: all work happens on `saasi-typed-models`. Suite must be green (`bundle exec rspec`) before every commit. Run from the repo root `/Users/anthonyrichardson/techony/saasu-rails` — NOT from `tmp/`.
- Every commit message ends with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- No `Saasu::` class may change behaviour. The only legacy-file edits in this plan are: `saasu2.gemspec` (Task 1) and the final `require` line in `lib/saasu.rb` (Task 1).
- Spec files map 1:1 to lib files: `lib/saasi/foo.rb` → `spec/saasi/foo_spec.rb`. Never create task-named spec files.
- Wire keys are exact PascalCase strings from the .NET SDK tables embedded in each task. Do not guess or "fix" apparent typos in them.
- The round-trip law (asserted per resource): `Model.from_wire(h).to_wire == h` for any wire hash `h` containing only WRITABLE declared keys and undeclared keys, with values in canonical wire form. Canonical wire form: JSON types; dates as `YYYY-MM-DD` strings; datetimes as whole-second ISO8601 strings (offset preserved; fractional seconds are NOT canonical); decimals as JSON numbers. Read-only fields are covered by a separate assertion (readable, excluded from `to_wire`) — a hash containing them does not round-trip by design.
- Decimals serialize via `BigDecimal#to_f` — parity with the legacy layer, which already lives on floats parsed from JSON. Known ceiling: values beyond Float precision are out of contract (Saasu money is 2–3dp).
- `to_wire` omits nil attributes and empty `has_many` collections; `false` is a value and MUST be emitted.
- Type mapping from .NET (fixed table; every task uses it):
  `string`→`:string` · `int`/`short`/`Int16`/`long`/`byte`→`:integer` · `decimal`→`:decimal` · `bool`→`:boolean` · `DateTime` named `*Utc`/`LastModified*`/`Timestamp`→`:datetime` · other `DateTime`→`:date` · `List<string>`→`:string_array` · nested model→`has_one` · `List<Model>`→`has_many`.
- Enum validations use `Saasu::Constants` values and always `allow_nil: true`. Presence validations only where the .NET `[Required]` annotation exists, UNCONDITIONAL (no `on:` context) — the API requires these fields on both insert and full-payload update, and updates serialize the full payload.
- Resource classes subclass `Saasi::Base` directly. Deeper hierarchies (resource subclassing resource) are unsupported: `wraps` is not inherited and re-declaring an attribute with a different `wire_key` is undefined behaviour.
- Every resource spec must include at least one WebMock delegation test proving the typed class hits the legacy URL — a find or a list. Where a task's spec code doesn't already include one, add a list test shaped like this (substitute the resource's index URL, collection key, and wire fixture):

```ruby
  it 'lists via the legacy class' do
    stub_request(:get, 'https://api.saasu.com/<index-path>?FileId=777').
      to_return(status: 200, body: { '<CollectionKey>' => [wire] }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    expect(described_class.all.first).to be_a(described_class)
  end
```

(with the standard config/auth `before` block from Task 5's spec if the file doesn't have one yet).
- TDD per task: write the spec first, run it and see it fail, implement, see it pass, run the full suite, commit.

---

### Task 1: Gem wiring — dependency, entry point, errors, collection

**Files:**
- Modify: `saasu2.gemspec` (add activemodel dependency; move webmock out of runtime deps if it is one)
- Modify: `lib/saasu.rb` (append `require "saasi"` as the last require)
- Create: `lib/saasi.rb`
- Create: `lib/saasi/errors.rb`
- Create: `lib/saasi/collection.rb`
- Test: `spec/saasi/saasi_spec.rb`

**Interfaces:**
- Produces: `Saasi.configure` (delegates to `Saasu::Config.configure`), `Saasi::Error` (= `Saasu::Error`), `Saasi::NotFoundError` (= `Saasu::NotFoundError`), `Saasi::ValidationError#model`/`#errors`, `Saasi::Collection#metadata`.

- [ ] **Step 1: Write the failing spec**

```ruby
# spec/saasi/saasi_spec.rb
require 'spec_helper'

describe Saasi do
  it 'aliases the HTTP error classes' do
    expect(Saasi::Error).to be Saasu::Error
    expect(Saasi::NotFoundError).to be Saasu::NotFoundError
  end

  it 'delegates configuration to Saasu::Config' do
    Saasi.configure { |c| c.file_id = 4242 }
    expect(Saasu::Config.file_id).to eq 4242
  ensure
    Saasu::Config.file_id = nil
  end

  it 'exposes a Collection with metadata' do
    collection = Saasi::Collection.new([1, 2], { 'TotalRecords' => 9 })
    expect(collection).to eq [1, 2]
    expect(collection.metadata).to eq({ 'TotalRecords' => 9 })
  end

  it 'raises ValidationError carrying the model and its errors' do
    model = Struct.new(:errors).new(double(full_messages: ['Name is bad']))
    error = Saasi::ValidationError.new(model)
    expect(error.model).to be model
    expect(error.message).to include('Name is bad')
  end
end
```

- [ ] **Step 2: Run it, expect failure**

Run: `bundle exec rspec spec/saasi/saasi_spec.rb`
Expected: FAIL — `uninitialized constant Saasi`

- [ ] **Step 3: Implement**

```ruby
# lib/saasi/errors.rb
module Saasi
  Error = Saasu::Error
  NotFoundError = Saasu::NotFoundError

  class ValidationError < StandardError
    attr_reader :model

    def initialize(model)
      @model = model
      super("Validation failed: #{model.errors.full_messages.join(', ')}")
    end

    def errors
      model.errors
    end
  end
end
```

```ruby
# lib/saasi/collection.rb
module Saasi
  class Collection < Array
    attr_reader :metadata

    def initialize(records, metadata = {})
      super(records)
      @metadata = metadata
    end
  end
end
```

```ruby
# lib/saasi.rb
require 'active_model'

require 'saasi/errors'
require 'saasi/collection'

module Saasi
  def self.configure(&block)
    Saasu::Config.configure(&block)
  end
end
```

In `lib/saasu.rb`, after the last existing require (`require "saasu/reports"`), add:

```ruby
require "saasi"
```

In `saasu2.gemspec`, add alongside the existing dependencies:

```ruby
spec.add_dependency "activemodel", ">= 6.1"
```

(6.1 floor, not 6.0: the specs use `errors.attribute_names`, which arrived in the ActiveModel 6.1 error-object API.)

and if `webmock` is declared with `add_dependency`, change it to `add_development_dependency`.

- [ ] **Step 4: Run the spec, then the whole suite**

Run: `bundle install && bundle exec rspec spec/saasi/saasi_spec.rb && bundle exec rspec`
Expected: new spec PASS; full suite green (91+ examples).

- [ ] **Step 5: Commit**

```bash
git add saasu2.gemspec Gemfile.lock lib/saasu.rb lib/saasi.rb lib/saasi spec/saasi
git commit -m "Add Saasi namespace skeleton: activemodel dependency, errors, collection

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Saasi::Base — attributes, wire map, extra, round-trip

**Files:**
- Create: `lib/saasi/base.rb`
- Modify: `lib/saasi.rb` (require it)
- Test: `spec/saasi/base_spec.rb`

**Interfaces:**
- Consumes: `Saasi::ValidationError` (Task 1).
- Produces (later tasks build on these exact signatures):
  - `.wraps(klass = nil)` — get/set legacy class
  - `.attribute(name, type, wire_key: nil, **opts)` — ActiveModel attribute + wire-map entry
  - `.wire_map` → `{ 'WireKey' => :attr_name }` (inherited, per-class copy)
  - `.from_wire(hash)` → instance; `#assign_wire(hash)`; `#to_wire` → wire hash
  - `#extra` → Hash of undeclared wire keys
  - `:string_array` registered ActiveModel type

- [ ] **Step 1: Write the failing spec**

```ruby
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
```

- [ ] **Step 2: Run it, expect failure**

Run: `bundle exec rspec spec/saasi/base_spec.rb`
Expected: FAIL — `uninitialized constant Saasi::Base`

- [ ] **Step 3: Implement**

```ruby
# lib/saasi/base.rb
module Saasi
  class StringArrayType < ActiveModel::Type::Value
    def cast(value)
      return if value.nil? # nil stays nil so to_wire omits the field; Array(nil) would emit []
      Array(value).map(&:to_s)
    end
  end
  ActiveModel::Type.register(:string_array, StringArrayType)

  class Base
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_reader :extra

    def initialize(attributes = {})
      @extra = {}
      super
    end

    class << self
      def wraps(klass = nil)
        @legacy_class = klass if klass
        @legacy_class
      end

      def wire_map
        @wire_map ||= superclass.respond_to?(:wire_map) ? superclass.wire_map.dup : {}
      end

      def attribute(name, type = ActiveModel::Type::Value.new, wire_key: nil, **options)
        wire_map[wire_key || name.to_s.camelize] = name
        super(name, type, **options)
      end

      def from_wire(hash)
        new.assign_wire(hash)
      end
    end

    def assign_wire(hash)
      hash.each do |key, value|
        key = key.to_s
        if (attr_name = self.class.wire_map[key])
          public_send("#{attr_name}=", value)
        elsif self.class.attribute_types.key?(key)
          # snake_case attribute name (user-supplied hash rather than API wire hash)
          public_send("#{key}=", value)
        else
          extra[key] = value
        end
      end
      self
    end

    def to_wire
      # declared keys always win over stray extra entries, even when the declared value is nil
      wire = extra.reject { |key, _| self.class.wire_map.key?(key) }
      self.class.wire_map.each do |key, attr_name|
        value = public_send(attr_name)
        wire[key] = serialize_wire_value(value) unless value.nil?
      end
      wire
    end

    private

    def serialize_wire_value(value)
      case value
      when Time, DateTime then value.iso8601   # DateTime before Date: DateTime < Date
      when Date           then value.strftime('%Y-%m-%d')
      when BigDecimal     then value.to_f
      else value
      end
    end
  end
end
```

In `lib/saasi.rb`, after `require 'saasi/collection'`, add:

```ruby
require 'saasi/base'
```

- [ ] **Step 4: Run the spec, then the whole suite**

Run: `bundle exec rspec spec/saasi/base_spec.rb && bundle exec rspec`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/saasi.rb lib/saasi/base.rb spec/saasi/base_spec.rb
git commit -m "Add Saasi::Base: typed attributes, wire-key map, extra passthrough

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Saasi::Base — has_one / has_many nested models, read_only

**Files:**
- Modify: `lib/saasi/base.rb`
- Test: `spec/saasi/base_spec.rb` (append)

**Interfaces:**
- Produces:
  - `.has_one(name, klass, wire_key: nil)` — reader/writer coercing Hash → `klass.from_wire`
  - `.has_many(name, klass, wire_key: nil)` — reader (defaults `[]`), writer coercing arrays of Hash
  - `.nested_map` → `{ 'WireKey' => { name:, klass:, many: } }` (inherited copy)
  - `.read_only(*attr_names)` — names excluded from `#to_wire` (attributes or nested)

- [ ] **Step 1: Append the failing specs to `spec/saasi/base_spec.rb`**

```ruby
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
```

- [ ] **Step 2: Run, expect failure** — `undefined method 'has_many'`

- [ ] **Step 3: Implement in `lib/saasi/base.rb`** (inside `class << self` add; and extend `to_wire`)

```ruby
      def nested_map
        @nested_map ||= superclass.respond_to?(:nested_map) ? superclass.nested_map.dup : {}
      end

      def read_only_names
        @read_only_names ||= superclass.respond_to?(:read_only_names) ? superclass.read_only_names.dup : []
      end

      def read_only(*names)
        read_only_names.concat(names.map(&:to_sym))
      end

      def has_one(name, klass, wire_key: nil)
        nested_map[wire_key || name.to_s.camelize] = { name: name, klass: klass, many: false }
        attr_reader name
        define_method("#{name}=") do |value|
          value = klass.from_wire(value.stringify_keys) if value.is_a?(Hash)
          instance_variable_set("@#{name}", value)
        end
      end

      def has_many(name, klass, wire_key: nil)
        nested_map[wire_key || name.to_s.camelize] = { name: name, klass: klass, many: true }
        define_method(name) do
          instance_variable_get("@#{name}") || instance_variable_set("@#{name}", [])
        end
        define_method("#{name}=") do |values|
          coerced = Array(values).map { |v| v.is_a?(Hash) ? klass.from_wire(v.stringify_keys) : v }
          instance_variable_set("@#{name}", coerced)
        end
      end
```

`assign_wire` gains a nested branch before the attribute branch:

```ruby
    def assign_wire(hash)
      hash.each do |key, value|
        key = key.to_s
        if (nested = self.class.nested_map[key])
          public_send("#{nested[:name]}=", value)
        elsif (attr_name = self.class.wire_map[key])
          public_send("#{attr_name}=", value)
        elsif self.class.attribute_types.key?(key) || self.class.nested_map.any? { |_, n| n[:name].to_s == key }
          # snake_case attribute or nested name (user-supplied hash, e.g. quick_payment = { date_paid: ... })
          public_send("#{key}=", value)
        else
          extra[key] = value
        end
      end
      self
    end
```

Nested validation cascades — add to the `Base` class body (instance side):

```ruby
    validate :nested_models_are_valid

    def nested_models_are_valid
      self.class.nested_map.each_value do |nested|
        Array(public_send(nested[:name])).each_with_index do |model, index|
          next if model.valid?
          model.errors.each do |error|
            errors.add(nested[:name], "#{index}: #{error.attribute} #{error.message}")
          end
        end
      end
    end
```

`to_wire` gains nested serialisation and the read_only filter:

```ruby
    def to_wire
      # declared keys always win over stray extra entries, even when the declared value is nil
      wire = extra.reject { |key, _| self.class.wire_map.key?(key) || self.class.nested_map.key?(key) }
      self.class.wire_map.each do |key, attr_name|
        next if self.class.read_only_names.include?(attr_name)
        # raw attribute value, NOT public_send: resources override readers (e.g.
        # Invoice#id falls back to transaction_id) and to_wire must not leak that
        value = attributes[attr_name.to_s]
        wire[key] = serialize_wire_value(value) unless value.nil?
      end
      self.class.nested_map.each do |key, nested|
        next if self.class.read_only_names.include?(nested[:name])
        value = public_send(nested[:name])
        if nested[:many]
          wire[key] = value.map(&:to_wire) unless value.empty?
        elsif value
          wire[key] = value.to_wire
        end
      end
      wire
    end
```

- [ ] **Step 4: Run `bundle exec rspec spec/saasi/base_spec.rb && bundle exec rspec`** — all green.

- [ ] **Step 5: Commit**

```bash
git add lib/saasi/base.rb spec/saasi/base_spec.rb
git commit -m "Add nested has_one/has_many models and read_only to Saasi::Base

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Saasi::Base — CRUD delegation to the legacy classes

**Files:**
- Modify: `lib/saasi/base.rb`
- Test: `spec/saasi/base_spec.rb` (append)

**Interfaces:**
- Consumes: legacy `Saasu::Base` API — `.find(id)`, `.all`/`.where` → `Saasu::Collection` (`#metadata`), `.new(hash)#save` → true (mutates its `attributes`), `#delete` → true/false.
- Produces (every resource task relies on these):
  - `.find(id)` → typed instance (raises `Saasi::NotFoundError` via legacy)
  - `.all` / `.where(filters)` → `Saasi::Collection` of typed instances (+ `metadata`)
  - `.create(attrs)` → saved typed instance
  - `#save` → `true`, raises `Saasi::ValidationError` when `valid?(context)` is false; context is `:create` when `persisted?` is false, else `:update`
  - `#update(attrs)`, `#delete`, `#persisted?`

- [ ] **Step 1: Append the failing specs** (WebMock; reuse the auth stub pattern from `spec/base_spec.rb`)

```ruby
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
    stub_request(:get, 'https://api.saasu.com/widgetlegacys?FileId=777').
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
```

- [ ] **Step 2: Run, expect failure** — `undefined method 'find' for Saasi::Widget`

- [ ] **Step 3: Implement in `lib/saasi/base.rb`**

```ruby
      # class-level additions
      def find(id)
        record = wraps.find(id)
        from_wire(record.attributes) if record # legacy find returns nil on a blank 200 response
      end

      def all
        wrap_collection(wraps.all)
      end

      def where(params)
        wrap_collection(wraps.where(params))
      end

      def create(attrs = {})
        new(attrs).tap(&:save)
      end

      private

      def wrap_collection(legacy_collection)
        metadata = legacy_collection.respond_to?(:metadata) ? legacy_collection.metadata : {}
        Collection.new(legacy_collection.map { |record| from_wire(record.attributes) }, metadata)
      end
```

```ruby
    # instance-level additions (public)
    def save
      context = persisted? ? :update : :create
      raise Saasi::ValidationError.new(self) unless valid?(context)

      legacy = self.class.wraps.new(to_wire)
      legacy.save
      refresh_from(legacy.attributes)
      true
    end

    def update(attrs)
      assign_attributes(attrs)
      save
    end

    def delete
      result = self.class.wraps.new(to_wire).delete
      clear_identity! if result
      result
    end

    def persisted?
      !id.nil?
    end

    def refresh_from(wire_hash)
      # full reset first: fields absent from the response (write-only instructions,
      # cleared values) must NOT survive as stale state
      @extra = {}
      self.class.nested_map.each_value do |nested|
        instance_variable_set("@#{nested[:name]}", nil)
      end
      self.class.attribute_types.each_key do |name|
        public_send("#{name}=", nil)
      end
      assign_wire(wire_hash)
    end

    private

    # id AND transaction_id: transaction resources fall back to transaction_id in #id,
    # so clearing only id would leave the model looking persisted after deletion
    def clear_identity!
      %w(id transaction_id).each do |name|
        public_send("#{name}=", nil) if self.class.attribute_types.key?(name)
      end
    end
```

Note: `#id` is the ActiveModel-generated reader for `attribute :id` declared by
each resource. Transaction resources (Invoice, Payment, Journal, ItemAdjustment,
ItemTransfer) also declare `attribute :transaction_id, :integer` and override:

```ruby
def id
  super || transaction_id
end
```

- [ ] **Step 4: Run `bundle exec rspec`** — all green.

- [ ] **Step 5: Commit**

```bash
git add lib/saasi/base.rb spec/saasi/base_spec.rb
git commit -m "Add CRUD delegation from Saasi::Base to legacy Saasu classes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## THE STANDARD RESOURCE CYCLE (Tasks 5–19 all follow it)

Every resource task executes exactly these five steps with the task's own parameters (lib file, class code, spec code, commit message — all given verbatim in the task):

1. Write the task's spec file exactly as given.
2. Run `bundle exec rspec spec/saasi/<name>_spec.rb` — expect FAIL (`uninitialized constant`).
3. Create `lib/saasi/<name>.rb` with the class code exactly as given, and add `require 'saasi/<name>'` to `lib/saasi.rb` (after `require 'saasi/base'`, keeping resource requires in the order the tasks add them).
4. Run the task's spec (PASS), then `bundle exec rspec` (whole suite green).
5. Commit:

```bash
git add lib/saasi.rb lib/saasi/<name>.rb spec/saasi/<name>_spec.rb
git commit -m "<task's commit message>

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Conventions used in every resource class (already implemented by Tasks 1–4):

- Fields marked **read-only** in the .NET tables are declared as normal attributes plus listed in `read_only` — readable, never serialized. Identifiers (`Id`, `TransactionId`) and `LastUpdatedId` (concurrency token) are NEVER read_only: `to_wire` must carry them for update/delete delegation.
- `[Required]` .NET annotations become unconditional `validates ... presence: true` (the API requires them on both insert and full-payload update). Enum fields get `inclusion` + `allow_nil: true` from `Saasu::Constants` (or a literal list where no constant exists).
- Nested value objects are `Saasi::Base` subclasses namespaced inside their parent (`Saasi::Invoice::LineItem`) with NO `wraps` and no CRUD — they exist for typing/round-trip only. Client-side validations on nested models are NOT cascaded by the parent's `valid?` in this iteration (documented limitation; the QuickPayment presence validations run only if the user calls `quick_payment.valid?` directly).
- Transaction resources (Invoice, Payment, Journal, ItemAdjustment, ItemTransfer) declare both `id` and `transaction_id` (whichever the API returns) and override `def id; super || transaction_id; end`.

---

### Task 5: Saasi::Invoice (+ LineItem, QuickPayment, EmailMessage, Terms, AttachmentInfo)

**Files:** Create `lib/saasi/invoice.rb`, `spec/saasi/invoice_spec.rb`; modify `lib/saasi.rb`.

**Interfaces:** Consumes Task 1–4 (`Saasi::Base` DSL, CRUD). Produces `Saasi::Invoice` and nested classes other tasks don't depend on.

**Class code** (`lib/saasi/invoice.rb`):

```ruby
module Saasi
  class Invoice < Saasi::Base
    class LineItemAttribute < Saasi::Base
      attribute :attribute_id, :integer
      attribute :name,         :string
      attribute :value,        :string
    end

    class LineItem < Saasi::Base
      attribute :id,                  :integer
      attribute :description,         :string
      attribute :account_id,          :integer
      attribute :tax_code,            :string
      attribute :total_amount,        :decimal
      attribute :quantity,            :decimal
      attribute :unit_price,          :decimal
      attribute :percentage_discount, :decimal
      attribute :inventory_id,        :integer
      attribute :item_code,           :string
      attribute :tags,                :string_array
      has_many  :item_attributes, LineItemAttribute, wire_key: 'Attributes'
    end

    class QuickPayment < Saasi::Base
      attribute :date_paid,            :date
      attribute :date_cleared,         :date
      attribute :banked_to_account_id, :integer
      attribute :amount,               :decimal
      attribute :reference,            :string
      attribute :summary,              :string

      validates :date_paid, :banked_to_account_id, :amount, presence: true
      validate  :amount_has_at_most_two_decimals

      def amount_has_at_most_two_decimals
        errors.add(:amount, 'must have at most 2 decimal places') if amount && amount != amount.round(2)
      end
    end

    class EmailMessage < Saasi::Base
      attribute :from,    :string
      attribute :to,      :string
      attribute :subject, :string
      attribute :body,    :string
      attribute :cc,      :string
      attribute :bcc,     :string
    end

    class Terms < Saasi::Base
      attribute :type,               :integer
      attribute :interval,           :integer
      attribute :interval_type,      :integer
      attribute :type_enum,          :string
      attribute :interval_type_enum, :string
    end

    class AttachmentInfo < Saasi::Base
      attribute :id,                  :integer
      attribute :name,                :string
      attribute :description,         :string
      attribute :item_id_attached_to, :integer
      attribute :size,                :integer
    end

    wraps Saasu::Invoice

    attribute :id,                                 :integer
    attribute :transaction_id,                     :integer
    attribute :last_updated_id,                    :string
    attribute :currency,                           :string
    attribute :invoice_number,                     :string
    attribute :invoice_type,                       :string
    attribute :transaction_type,                   :string
    attribute :layout,                             :string
    attribute :summary,                            :string
    attribute :total_amount,                       :decimal
    attribute :total_tax_amount,                   :decimal
    attribute :is_tax_inc,                         :boolean
    attribute :amount_paid,                        :decimal
    attribute :amount_owed,                        :decimal
    attribute :fx_rate,                            :decimal
    attribute :auto_populate_fx_rate,              :boolean
    attribute :requires_follow_up,                 :boolean
    attribute :sent_to_contact,                    :boolean
    attribute :transaction_date,                   :date
    attribute :billing_contact_id,                 :integer
    attribute :billing_contact_first_name,         :string
    attribute :billing_contact_last_name,          :string
    attribute :billing_contact_organisation_name,  :string
    attribute :shipping_contact_id,                :integer
    attribute :shipping_contact_first_name,        :string
    attribute :shipping_contact_last_name,         :string
    attribute :shipping_contact_organisation_name, :string
    attribute :created_date_utc,                   :datetime
    attribute :last_modified_date_utc,             :datetime
    attribute :payment_status,                     :string
    attribute :due_date,                           :date
    attribute :invoice_status,                     :string
    attribute :purchase_order_number,              :string
    attribute :payment_count,                      :integer
    attribute :tags,                               :string_array
    attribute :notes_internal,                     :string
    attribute :notes_external,                     :string
    attribute :template_id,                        :integer
    attribute :send_email_to_contact,              :boolean

    has_many :line_items,    LineItem
    has_one  :terms,         Terms
    has_many :attachments,   AttachmentInfo
    has_one  :email_message, EmailMessage
    has_one  :quick_payment, QuickPayment

    read_only :billing_contact_first_name, :billing_contact_last_name,
              :billing_contact_organisation_name, :shipping_contact_first_name,
              :shipping_contact_last_name, :shipping_contact_organisation_name,
              :created_date_utc, :last_modified_date_utc, :payment_status,
              :invoice_status, :payment_count, :attachments

    validates :invoice_type, :transaction_type, :layout, :transaction_date, presence: true
    validates :line_items, presence: true
    validates :transaction_type, inclusion: { in: Saasu::Constants::INVOICE_TRANSACTION_TYPES.values }, allow_nil: true
    validates :layout, inclusion: { in: Saasu::Constants::INVOICE_LAYOUTS.values }, allow_nil: true
    validates :invoice_type, inclusion: { in: Saasu::Constants::INVOICE_TYPES }, allow_nil: true

    def id
      super || transaction_id
    end

    # QuickPayment is accepted by the API on POST only (never PUT, never returned on GET)
    def save
      raise "QuickPayment can only be set when creating an invoice (the API accepts it on POST only)" if persisted? && quick_payment
      super
    end

    # Non-CRUD helpers, delegated so migrated apps keep full method parity
    def self.sales_stats_summary(params = {})
      Saasu::Invoice.sales_stats_summary(params)
    end

    def email(email_address = nil)
      self.class.wraps.new('Id' => id).email(email_address)
    end

    def generate_pdf(template_id = nil)
      self.class.wraps.new('Id' => id).generate_pdf(template_id)
    end
  end
end
```

**Spec code** (`spec/saasi/invoice_spec.rb`):

```ruby
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
```

**Commit message:** `Add Saasi::Invoice typed model with nested line items, terms, quick payment`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 6: Saasi::Contact (+ Address, TradingTerms, BpayDetails, ChequeDetails, DirectDepositDetails)

**Files:** Create `lib/saasi/contact.rb`, `spec/saasi/contact_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/contact.rb`):

```ruby
module Saasi
  class Contact < Saasi::Base
    class Address < Saasi::Base
      attribute :street,   :string
      attribute :city,     :string
      attribute :state,    :string
      attribute :postcode, :string, wire_key: 'Postcode'
      attribute :country,  :string
    end

    class TradingTerms < Saasi::Base
      attribute :trading_terms_type,          :integer
      attribute :trading_terms_interval,      :integer
      attribute :trading_terms_interval_type, :integer
    end

    class BpayDetails < Saasi::Base
      attribute :biller_code, :string
      attribute :crn,         :string, wire_key: 'CRN'
    end

    class ChequeDetails < Saasi::Base
      attribute :accept_cheque,     :boolean
      attribute :cheque_payable_to, :string
    end

    class DirectDepositDetails < Saasi::Base
      attribute :accept_direct_deposit, :boolean
      attribute :account_name,          :string
      attribute :account_bsb,           :string, wire_key: 'AccountBSB'
      attribute :account_number,        :string
    end

    wraps Saasu::Contact

    attribute :id,                        :integer
    attribute :created_date_utc,          :datetime
    attribute :last_modified_date_utc,    :datetime
    attribute :last_updated_id,           :string
    attribute :salutation,                :string
    attribute :given_name,                :string
    attribute :middle_initials,           :string
    attribute :family_name,               :string
    attribute :is_active,                 :boolean
    attribute :company_id,                :integer
    attribute :position_title,            :string
    attribute :website_url,               :string
    attribute :primary_phone,             :string
    attribute :home_phone,                :string
    attribute :other_phone,               :string
    attribute :mobile_phone,              :string
    attribute :fax,                       :string
    attribute :email_address,             :string
    attribute :contact_id,                :string  # free-text reference; a string in the API
    attribute :contact_manager_id,        :integer
    attribute :custom_field1,             :string, wire_key: 'CustomField1'
    attribute :custom_field2,             :string, wire_key: 'CustomField2'
    attribute :twitter_id,                :string
    attribute :skype_id,                  :string
    attribute :linked_in_profile,         :string
    attribute :auto_send_statement,       :boolean
    attribute :is_partner,                :boolean
    attribute :is_customer,               :boolean
    attribute :is_supplier,               :boolean
    attribute :is_contractor,             :boolean
    attribute :tags,                      :string_array
    attribute :default_sale_discount,     :decimal
    attribute :default_purchase_discount, :decimal
    attribute :last_modified_by_user_id,  :integer

    has_one :direct_deposit_details, DirectDepositDetails
    has_one :cheque_details,         ChequeDetails
    has_one :bpay_details,           BpayDetails
    has_one :postal_address,         Address
    has_one :other_address,          Address
    has_one :sale_trading_terms,     TradingTerms
    has_one :purchase_trading_terms, TradingTerms

    read_only :created_date_utc, :last_modified_date_utc, :last_modified_by_user_id

    validates :salutation, inclusion: { in: ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.'] }, allow_nil: true

    # Non-CRUD helper parity with the legacy class
    def generate_pdf(template_id = nil)
      self.class.wraps.new('Id' => id).generate_pdf(template_id)
    end
  end
end
```

**Spec code** (`spec/saasi/contact_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Contact do
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
      'Id' => 5, 'GivenName' => 'Jack', 'FamilyName' => 'Sparrow', 'IsActive' => true,
      'ContactId' => 'CUST-001', 'Tags' => ['vip'],
      'PostalAddress' => { 'Street' => '1 Main St', 'City' => 'Sydney', 'Postcode' => '2000' },
      'DirectDepositDetails' => { 'AcceptDirectDeposit' => true, 'AccountBSB' => '062-000' },
      'BpayDetails' => { 'BillerCode' => '1234', 'CRN' => '999' },
      'SaleTradingTerms' => { 'TradingTermsType' => 1, 'TradingTermsInterval' => 14, 'TradingTermsIntervalType' => 1 },
      'NewField' => 'kept'
    }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Contact.from_wire(wire).to_wire).to eq wire
  end

  it 'types nested value objects and keeps ContactId a string' do
    contact = Saasi::Contact.from_wire(wire)
    expect(contact.contact_id).to eq 'CUST-001'
    expect(contact.postal_address.city).to eq 'Sydney'
    expect(contact.direct_deposit_details.account_bsb).to eq '062-000'
    expect(contact.bpay_details.crn).to eq '999'
    expect(contact.sale_trading_terms.trading_terms_interval).to eq 14
  end

  it 'validates salutation' do
    expect(Saasi::Contact.new(salutation: 'Lord')).not_to be_valid
    expect(Saasi::Contact.new(salutation: 'Dr.')).to be_valid
  end

  it 'creates via the legacy class' do
    stub_request(:post, 'https://api.saasu.com/contact?FileId=777').
      with(body: { GivenName: 'Jack' }).
      to_return(status: 200, body: { InsertedEntityId: 9 }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://api.saasu.com/contact/9?FileId=777').
      to_return(status: 200, body: { Id: 9, GivenName: 'Jack' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Saasi::Contact.create(given_name: 'Jack').id).to eq 9
  end
end
```

**Commit message:** `Add Saasi::Contact typed model with address, banking and trading-terms nests`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 7: Saasi::Payment (+ PaymentItem)

**Files:** Create `lib/saasi/payment.rb`, `spec/saasi/payment_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/payment.rb`):

```ruby
module Saasi
  class Payment < Saasi::Base
    class PaymentItem < Saasi::Base
      attribute :invoice_transaction_id, :integer
      attribute :amount_paid,            :decimal

      validates :invoice_transaction_id, :amount_paid, presence: true
    end

    wraps Saasu::Payment

    attribute :id,                     :integer
    attribute :transaction_id,         :integer
    attribute :transaction_date,       :date
    attribute :transaction_type,       :string
    attribute :payment_account_id,     :integer
    attribute :total_amount,           :decimal
    attribute :fee_amount,             :decimal
    attribute :summary,                :string
    attribute :reference,              :string
    attribute :cleared_date,           :date
    attribute :currency,               :string
    attribute :auto_populate_fx_rate,  :boolean
    attribute :fx_rate,                :decimal
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :last_updated_id,        :string
    attribute :requires_follow_up,     :boolean
    attribute :notes,                  :string

    has_many :payment_items, PaymentItem

    read_only :created_date_utc, :last_modified_date_utc

    validates :transaction_date, :transaction_type, :payment_account_id, presence: true
    validates :payment_items, presence: true
    validates :transaction_type, inclusion: { in: Saasu::Constants::PAYMENT_TRANSACTION_TYPES.values }, allow_nil: true

    def id
      super || transaction_id
    end
  end
end
```

**Spec code** (`spec/saasi/payment_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Payment do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'TransactionId' => 44, 'TransactionDate' => '2026-08-01', 'TransactionType' => 'SP',
      'PaymentAccountId' => 456, 'TotalAmount' => 100.0,
      'PaymentItems' => [{ 'InvoiceTransactionId' => 33, 'AmountPaid' => 100.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Payment.from_wire(wire).to_wire).to eq wire
  end

  it 'requires the .NET-required fields and validates the SP/PP enum' do
    payment = Saasi::Payment.new
    expect(payment.valid?).to be false
    expect(payment.errors.attribute_names).to include(:transaction_date, :transaction_type, :payment_account_id, :payment_items)
    expect(Saasi::Payment.from_wire(wire.merge('TransactionType' => 'S'))).not_to be_valid
  end

  it 'uses TransactionId as id' do
    expect(Saasi::Payment.from_wire(wire).id).to eq 44
  end

  it 'lists via the legacy class with metadata' do
    stub_request(:get, 'https://api.saasu.com/payments?FileId=777').
      to_return(status: 200, body: { PaymentTransactions: [wire], Total: 1 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
    payments = Saasi::Payment.all
    expect(payments.first.payment_items.first.amount_paid).to eq BigDecimal('100')
    expect(payments.metadata).to eq({ 'Total' => 1 })
  end
end
```

**Commit message:** `Add Saasi::Payment typed model with payment allocation items`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 8: Saasi::Item (+ BuildItem)

**Files:** Create `lib/saasi/item.rb`, `spec/saasi/item_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/item.rb`):

```ruby
module Saasi
  class Item < Saasi::Base
    class BuildItem < Saasi::Base
      attribute :id,          :integer
      attribute :code,        :string
      attribute :description, :string
      attribute :quantity,    :decimal
    end

    wraps Saasu::Item

    attribute :id,                          :integer
    attribute :code,                        :string
    attribute :description,                 :string
    attribute :type,                        :string
    attribute :is_active,                   :boolean
    attribute :is_inventoried,              :boolean
    attribute :asset_account_id,            :integer
    attribute :is_sold,                     :boolean
    attribute :sale_income_account_id,      :integer
    attribute :sale_tax_code_id,            :integer
    attribute :sale_cos_account_id,         :integer, wire_key: 'SaleCoSAccountId'
    attribute :is_bought,                   :boolean
    attribute :purchase_expense_account_id, :integer
    attribute :purchase_tax_code_id,        :integer
    attribute :minimum_stock_level,         :decimal
    attribute :stock_on_hand,               :decimal
    attribute :current_value,               :decimal
    attribute :primary_supplier_contact_id, :integer
    attribute :primary_supplier_item_code,  :string
    attribute :default_re_order_quantity,   :decimal
    attribute :last_updated_id,             :string
    attribute :is_visible,                  :boolean
    attribute :is_virtual,                  :boolean
    attribute :vtype,                       :string, wire_key: 'VType'
    attribute :selling_price,               :decimal
    attribute :is_selling_price_inc_tax,    :boolean
    attribute :created_date_utc,            :datetime
    attribute :last_modified_date_utc,      :datetime
    attribute :last_modified_by,            :integer
    attribute :buying_price,                :decimal
    attribute :is_buying_price_inc_tax,     :boolean
    attribute :is_voucher,                  :boolean
    attribute :valid_from,                  :date
    attribute :valid_to,                    :date
    attribute :on_order,                    :decimal
    attribute :committed,                   :decimal
    attribute :notes,                       :string

    has_many :build_items, BuildItem

    read_only :stock_on_hand, :current_value, :created_date_utc,
              :last_modified_date_utc, :last_modified_by, :on_order, :committed

    validates :type, inclusion: { in: Saasu::Constants::ITEM_TYPES.values }, allow_nil: true

    # POST Item/:id/build — quantity of this combo item to assemble
    def build(quantity:)
      self.class.wraps.new('Id' => id).build('Quantity' => quantity)
    end
  end
end
```

**Spec code** (`spec/saasi/item_spec.rb` — note: this is `spec/saasi/`, distinct from the legacy `spec/item_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Item do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  let(:wire) do
    { 'Id' => 3, 'Code' => 'BOOK', 'Type' => 'C', 'IsActive' => true, 'SaleCoSAccountId' => 12,
      'VType' => 'x', 'SellingPrice' => 25.5,
      'BuildItems' => [{ 'Id' => 4, 'Code' => 'PAGE', 'Quantity' => 100.0 }],
      'Extra' => 'kept' }
  end

  it 'round-trips losslessly (including the irregular wire keys)' do
    expect(Saasi::Item.from_wire(wire).to_wire).to eq wire
  end

  it 'validates the item type enum' do
    expect(Saasi::Item.new(type: 'Z')).not_to be_valid
    expect(Saasi::Item.new(type: 'I')).to be_valid
  end

  it 'delegates build to the legacy endpoint' do
    stub_request(:post, 'https://api.saasu.com/Item/3/build?FileId=777').
      with(body: { Quantity: 5 }).
      to_return(status: 200, body: { StatusMessage: 'Ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

    item = Saasi::Item.from_wire(wire)
    expect(item.build(quantity: 5)['StatusMessage']).to eq 'Ok'
  end
end
```

**Commit message:** `Add Saasi::Item typed model with build items and combo build delegation`

Execute THE STANDARD RESOURCE CYCLE with the above.


---

### Task 9: Saasi::Account

**Files:** Create `lib/saasi/account.rb`, `spec/saasi/account_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/account.rb`):

```ruby
module Saasi
  class Account < Saasi::Base
    wraps Saasu::Account

    attribute :id,                           :integer
    attribute :name,                         :string
    attribute :account_level,                :string
    attribute :account_type,                 :string
    attribute :is_active,                    :boolean
    attribute :is_built_in,                  :boolean
    attribute :last_updated_id,              :string
    attribute :default_tax_code,             :string
    attribute :ledger_code,                  :string
    attribute :currency,                     :string
    attribute :header_account_id,            :integer
    attribute :exchange_account_id,          :integer
    attribute :is_bank_account,              :boolean
    attribute :created_date_utc,             :datetime
    attribute :last_modified_date_utc,       :datetime
    attribute :include_in_forecaster,        :boolean
    attribute :bsb,                          :string, wire_key: 'BSB'
    attribute :number,                       :string
    attribute :bank_account_name,            :string
    attribute :bank_file_creation_enabled,   :boolean
    attribute :bank_code,                    :string
    attribute :user_number,                  :string
    attribute :merchant_fee_account_id,      :integer
    attribute :include_pending_transactions, :boolean

    read_only :is_built_in, :created_date_utc, :last_modified_date_utc

    validates :account_type, inclusion: { in: Saasu::Constants::ACCOUNT_TYPES }, allow_nil: true
    validates :account_level, inclusion: { in: %w(Header Detail) }, allow_nil: true

    # GET Accounts/BankAccountBalances — raw hash passthrough (report/utility endpoint)
    def self.bank_account_balances(params = {})
      Saasu::Account.bank_account_balances(params)
    end
  end
end
```

**Spec code** (`spec/saasi/account_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Account do
  let(:wire) do
    { 'Id' => 8, 'Name' => 'Sales', 'AccountType' => 'Income', 'AccountLevel' => 'Detail',
      'BSB' => '062-000', 'IsBankAccount' => false, 'Novel' => 'kept' }
  end

  it 'round-trips losslessly (BSB wire key intact)' do
    expect(Saasi::Account.from_wire(wire).to_wire).to eq wire
  end

  it 'validates account type and level' do
    expect(Saasi::Account.new(account_type: 'Fun')).not_to be_valid
    expect(Saasi::Account.new(account_type: 'Cost of Sales', account_level: 'Header')).to be_valid
  end
end
```

**Commit message:** `Add Saasi::Account typed model`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 10: Saasi::Company

**Files:** Create `lib/saasi/company.rb`, `spec/saasi/company_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/company.rb`):

```ruby
module Saasi
  class Company < Saasi::Base
    wraps Saasu::Company

    attribute :id,                        :integer
    attribute :name,                      :string
    attribute :abn,                       :string
    attribute :website,                   :string
    attribute :last_updated_id,           :string
    attribute :long_description,          :string
    attribute :logo_url,                  :string  # deprecated upstream; kept for reads
    attribute :trading_name,              :string
    attribute :company_email,             :string
    attribute :last_modified_date_utc,    :datetime
    attribute :created_date_utc,          :datetime
    attribute :last_modified_by_user_id,  :integer

    read_only :logo_url, :last_modified_date_utc, :created_date_utc, :last_modified_by_user_id
  end
end
```

**Spec code** (`spec/saasi/company_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Company do
  let(:wire) { { 'Id' => 2, 'Name' => 'Acme', 'Abn' => '51824753556', 'Novel' => 'kept' } }

  it 'round-trips losslessly' do
    expect(Saasi::Company.from_wire(wire).to_wire).to eq wire
  end

  it 'reads but never writes the deprecated LogoUrl' do
    company = Saasi::Company.from_wire(wire.merge('LogoUrl' => 'http://x/logo.png'))
    expect(company.logo_url).to eq 'http://x/logo.png'
    expect(company.to_wire).to eq wire
  end
end
```

**Commit message:** `Add Saasi::Company typed model`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 11: Saasi::Journal (+ JournalItem)

**Files:** Create `lib/saasi/journal.rb`, `spec/saasi/journal_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/journal.rb`):

```ruby
module Saasi
  class Journal < Saasi::Base
    class JournalItem < Saasi::Base
      attribute :type,       :string
      attribute :account_id, :integer
      attribute :tax_code,   :string
      attribute :amount,     :decimal

      validates :type, inclusion: { in: %w(Credit Debit) }, allow_nil: true
    end

    wraps Saasu::Journal

    attribute :id,                            :integer
    attribute :transaction_id,                :integer
    attribute :last_updated_id,               :string
    attribute :transaction_date,              :date
    attribute :summary,                       :string
    attribute :currency,                      :string
    attribute :fx_rate,                       :decimal
    attribute :auto_populate_fx_rate,         :boolean
    attribute :reference,                     :string
    attribute :journal_contact_id,            :integer
    attribute :contact_first_name,            :string
    attribute :contact_last_name,             :string
    attribute :contact_organisation_name,     :string
    attribute :requires_follow_up,            :boolean
    attribute :tags,                          :string_array
    attribute :created_date_utc,              :datetime
    attribute :last_modified_date_utc,        :datetime
    attribute :notes,                         :string

    has_many :items, JournalItem

    read_only :contact_first_name, :contact_last_name, :contact_organisation_name,
              :created_date_utc, :last_modified_date_utc

    validates :transaction_date, presence: true
    validates :items, presence: true

    def id
      super || transaction_id
    end
  end
end
```

**Spec code** (`spec/saasi/journal_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Journal do
  let(:wire) do
    { 'TransactionId' => 71, 'TransactionDate' => '2026-07-01', 'Summary' => 'Accrual',
      'Items' => [{ 'Type' => 'Debit', 'AccountId' => 8, 'Amount' => 50.0 },
                  { 'Type' => 'Credit', 'AccountId' => 9, 'Amount' => 50.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Journal.from_wire(wire).to_wire).to eq wire
  end

  it 'requires date and items; validates item type' do
    journal = Saasi::Journal.new
    expect(journal.valid?).to be false
    expect(journal.errors.attribute_names).to include(:transaction_date, :items)
    expect(Saasi::Journal::JournalItem.new(type: 'Sideways')).not_to be_valid
  end

  it 'uses TransactionId as id' do
    expect(Saasi::Journal.from_wire(wire).id).to eq 71
  end
end
```

**Commit message:** `Add Saasi::Journal typed model with debit/credit items`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 12: Saasi::TaxCode

**Files:** Create `lib/saasi/tax_code.rb`, `spec/saasi/tax_code_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/tax_code.rb`):

```ruby
module Saasi
  class TaxCode < Saasi::Base
    wraps Saasu::TaxCode

    attribute :id,                        :integer
    attribute :code,                      :string
    attribute :name,                      :string
    attribute :rate,                      :decimal
    attribute :posting_account_id,        :integer
    attribute :is_sale,                   :boolean
    attribute :is_purchase,               :boolean
    attribute :is_payroll,                :boolean
    attribute :is_inbuilt,                :boolean
    attribute :is_shared,                 :boolean
    attribute :is_active,                 :boolean
    attribute :created_date_utc,          :datetime
    attribute :last_modified_date_utc,    :datetime
    attribute :last_modified_by_user_id,  :integer
    attribute :last_updated_id,           :string
    attribute :notes,                     :string
  end
end
```

The legacy `Saasu::TaxCode` is read-only (`allowed_methods :show, :index`) — `save`/`delete` raise through the legacy layer, so no special handling is needed here.

**Spec code** (`spec/saasi/tax_code_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::TaxCode do
  let(:wire) { { 'Id' => 11, 'Code' => 'G1', 'Rate' => 10.0, 'IsSale' => true, 'Novel' => 'kept' } }

  it 'round-trips losslessly' do
    expect(Saasi::TaxCode.from_wire(wire).to_wire).to eq wire
  end

  it 'raises the legacy unsupported error on save' do
    expect { Saasi::TaxCode.from_wire(wire).save }.
      to raise_error(RuntimeError, /not currently supported/)
  end
end
```

**Commit message:** `Add Saasi::TaxCode typed model (read-only resource)`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 13: Saasi::Activity

**Files:** Create `lib/saasi/activity.rb`, `spec/saasi/activity_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/activity.rb`):

```ruby
module Saasi
  class Activity < Saasi::Base
    class AttachmentInfo < Saasi::Base
      attribute :id,                  :integer
      attribute :name,                :string
      attribute :description,         :string
      attribute :item_id_attached_to, :integer
      attribute :size,                :integer
    end

    wraps Saasu::Activity

    attribute :id,                     :integer
    attribute :last_updated_id,        :string
    attribute :activity_type,          :string
    attribute :done,                   :boolean
    attribute :due,                    :date
    attribute :title,                  :string
    attribute :owner_first_name,       :string
    attribute :owner_last_name,        :string
    attribute :owner_email,            :string
    attribute :attached_to_type,       :string
    attribute :attached_to_id,         :integer
    attribute :tags,                   :string_array
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :details,                :string

    has_many :attachments, AttachmentInfo

    # Owner names are derived from the user record looked up via OwnerEmail —
    # email is the assignment key (writable), the names are display fields.
    read_only :owner_first_name, :owner_last_name, :created_date_utc,
              :last_modified_date_utc, :attachments

    validates :attached_to_type, inclusion: { in: Saasu::Constants::ATTACHED_TO_TYPES }, allow_nil: true
  end
end
```

**Spec code** (`spec/saasi/activity_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Activity do
  let(:wire) do
    { 'Id' => 6, 'Title' => 'Call Jack', 'Done' => false, 'Due' => '2026-08-10',
      'AttachedToType' => 'Contact', 'AttachedToId' => 5, 'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::Activity.from_wire(wire).to_wire).to eq wire
  end

  it 'validates AttachedToType' do
    expect(Saasi::Activity.new(attached_to_type: 'Planet')).not_to be_valid
    expect(Saasi::Activity.new(attached_to_type: 'Sale')).to be_valid
  end
end
```

**Commit message:** `Add Saasi::Activity typed model`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 14: Saasi::ItemAdjustment (+ AdjustmentItem) and Saasi::ItemTransfer (+ TransferItem)

**Files:** Create `lib/saasi/item_adjustment.rb`, `lib/saasi/item_transfer.rb`, `spec/saasi/item_adjustment_spec.rb`, `spec/saasi/item_transfer_spec.rb`; modify `lib/saasi.rb`. (Two lib files → run the cycle twice, one commit per resource.)

**Class code** (`lib/saasi/item_adjustment.rb`):

```ruby
module Saasi
  class ItemAdjustment < Saasi::Base
    class AdjustmentItem < Saasi::Base
      attribute :quantity,    :decimal  # max 3 decimals per API docs
      attribute :item_id,     :integer
      attribute :account_id,  :integer
      attribute :unit_price,  :decimal
      attribute :total_price, :decimal
    end

    wraps Saasu::ItemAdjustment

    attribute :id,                     :integer
    attribute :transaction_id,         :integer
    attribute :date,                   :date
    attribute :summary,                :string
    attribute :requires_follow_up,     :boolean
    attribute :last_updated_id,        :string
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :tags,                   :string_array
    attribute :notes,                  :string

    has_many :adjustment_items, AdjustmentItem

    read_only :created_date_utc, :last_modified_date_utc

    def id
      super || transaction_id
    end
  end
end
```

**Class code** (`lib/saasi/item_transfer.rb`):

```ruby
module Saasi
  class ItemTransfer < Saasi::Base
    class TransferItem < Saasi::Base
      attribute :quantity,          :decimal  # max 3 decimals per API docs
      attribute :inventory_item_id, :integer
      attribute :unit_cost,         :decimal
      attribute :line_total,        :decimal

      validates :quantity, :inventory_item_id, :unit_cost, presence: true
    end

    wraps Saasu::ItemTransfer

    attribute :id,                     :integer
    attribute :transaction_id,         :integer
    attribute :last_updated_id,        :string
    attribute :date,                   :date
    attribute :summary,                :string
    attribute :tags,                   :string_array
    attribute :requires_follow_up,     :boolean
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :notes,                  :string

    has_many :items, TransferItem

    read_only :created_date_utc, :last_modified_date_utc

    validates :date, presence: true
    validates :items, presence: true

    def id
      super || transaction_id
    end
  end
end
```

**Spec code** (`spec/saasi/item_adjustment_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::ItemAdjustment do
  let(:wire) do
    { 'Id' => 12, 'Date' => '2026-08-01', 'Summary' => 'Stocktake',
      'AdjustmentItems' => [{ 'Quantity' => 2.5, 'ItemId' => 3, 'AccountId' => 8, 'UnitPrice' => 10.0, 'TotalPrice' => 25.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::ItemAdjustment.from_wire(wire).to_wire).to eq wire
  end

  it 'types adjustment items' do
    expect(Saasi::ItemAdjustment.from_wire(wire).adjustment_items.first.quantity).to eq BigDecimal('2.5')
  end
end
```

**Spec code** (`spec/saasi/item_transfer_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::ItemTransfer do
  let(:wire) do
    { 'Id' => 13, 'Date' => '2026-08-01',
      'Items' => [{ 'Quantity' => 1.0, 'InventoryItemId' => 3, 'UnitCost' => 9.0 }],
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::ItemTransfer.from_wire(wire).to_wire).to eq wire
  end

  it 'requires date and items' do
    transfer = Saasi::ItemTransfer.new
    expect(transfer.valid?).to be false
    expect(transfer.errors.attribute_names).to include(:date, :items)
  end
end
```

**Commit messages:** `Add Saasi::ItemAdjustment typed model` and `Add Saasi::ItemTransfer typed model`

Execute THE STANDARD RESOURCE CYCLE once per resource.

---

### Task 15: Saasi::ContactAggregate (+ Company, ContactManager, Address)

**Files:** Create `lib/saasi/contact_aggregate.rb`, `spec/saasi/contact_aggregate_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/contact_aggregate.rb`):

```ruby
module Saasi
  class ContactAggregate < Saasi::Base
    class Company < Saasi::Base
      attribute :id,               :integer
      attribute :name,             :string
      attribute :abn,              :string
      attribute :last_updated_id,  :string
      attribute :long_description, :string
      attribute :trading_name,     :string
      attribute :company_email,    :string
    end

    class ContactManager < Saasi::Base
      attribute :id,              :integer
      attribute :last_updated_id, :string
      attribute :salutation,      :string
      attribute :given_name,      :string
      attribute :middle_initials, :string
      attribute :family_name,     :string
      attribute :position_title,  :string
    end

    class Address < Saasi::Base
      attribute :street,   :string
      attribute :city,     :string
      attribute :state,    :string
      attribute :postcode, :string, wire_key: 'Postcode'
      attribute :country,  :string
    end

    wraps Saasu::ContactAggregate

    attribute :id,              :integer
    attribute :last_updated_id, :string
    attribute :salutation,      :string
    attribute :given_name,      :string
    attribute :middle_initials, :string
    attribute :family_name,     :string
    attribute :position_title,  :string
    attribute :primary_phone,   :string
    attribute :mobile_phone,    :string
    attribute :home_phone,      :string
    attribute :fax,             :string
    attribute :email_address,   :string
    attribute :contact_id,      :string  # free-text reference; a string in the API
    attribute :is_partner,      :boolean
    attribute :is_customer,     :boolean
    attribute :is_supplier,     :boolean
    attribute :is_contractor,   :boolean

    has_one :company,         Company
    has_one :contact_manager, ContactManager
    has_one :postal_address,  Address

    validates :salutation, inclusion: { in: ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.'] }, allow_nil: true
  end
end
```

Legacy `Saasu::ContactAggregate` allows only show/create/update — `all`/`delete` raise through the legacy layer unchanged.

**Spec code** (`spec/saasi/contact_aggregate_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::ContactAggregate do
  let(:wire) do
    { 'Id' => 5, 'GivenName' => 'Jack',
      'Company' => { 'Id' => 2, 'Name' => 'Acme', 'Abn' => '51824753556' },
      'ContactManager' => { 'Id' => 7, 'GivenName' => 'Boss' },
      'PostalAddress' => { 'Street' => '1 Main St', 'Postcode' => '2000' },
      'Novel' => 'kept' }
  end

  it 'round-trips losslessly' do
    expect(Saasi::ContactAggregate.from_wire(wire).to_wire).to eq wire
  end

  it 'types the three nested objects' do
    aggregate = Saasi::ContactAggregate.from_wire(wire)
    expect(aggregate.company.name).to eq 'Acme'
    expect(aggregate.contact_manager.given_name).to eq 'Boss'
    expect(aggregate.postal_address.postcode).to eq '2000'
  end

  it 'raises the legacy unsupported error on list' do
    expect { Saasi::ContactAggregate.all }.to raise_error(RuntimeError, /not currently supported/)
  end
end
```

**Commit message:** `Add Saasi::ContactAggregate typed model with company and manager nests`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 16: Saasi::DeletedEntity, Saasi::Brand, Saasi::FileIdentity

**Files:** Create `lib/saasi/deleted_entity.rb`, `lib/saasi/brand.rb`, `lib/saasi/file_identity.rb` and their three spec files; modify `lib/saasi.rb`. Run the cycle three times, one commit per resource.

**Class code** (`lib/saasi/deleted_entity.rb`):

```ruby
module Saasi
  class DeletedEntity < Saasi::Base
    wraps Saasu::DeletedEntity

    attribute :id,              :integer # never populated (tombstones carry no own id); satisfies Base#persisted?
    attribute :entity_type,     :string
    attribute :entity_id,       :integer
    attribute :deleted_by_user, :string
    attribute :timestamp,       :datetime

    validates :entity_type, inclusion: { in: Saasu::Constants::DELETED_ENTITY_TYPES }, allow_nil: true
  end
end
```

**Class code** (`lib/saasi/brand.rb`) — no .NET model exists; typed only for id/name, everything else flows through `extra`:

```ruby
module Saasi
  class Brand < Saasi::Base
    wraps Saasu::Brand

    attribute :id,   :integer
    attribute :name, :string
  end
end
```

**Class code** (`lib/saasi/file_identity.rb`) — union of the .NET Detail and Summary shapes (the API's GET-one returns Detail without an Id; the list returns Summaries with Id):

```ruby
module Saasi
  class FileIdentity < Saasi::Base
    class FileSettings < Saasi::Base
      attribute :sale_amounts_include_tax,     :boolean
      attribute :purchase_amounts_include_tax, :boolean
    end

    wraps Saasu::FileIdentity

    attribute :id,                                     :integer
    attribute :name,                                   :string
    attribute :full_legal_name,                        :string
    attribute :trading_name_or_alternative_brand_name, :string
    attribute :business_identifier,                    :string
    attribute :company_identifier,                     :string
    attribute :primary_phone,                          :string
    attribute :website,                                :string
    attribute :email,                                  :string
    attribute :street,                                 :string
    attribute :city,                                   :string
    attribute :state,                                  :string
    attribute :post_code,                              :string, wire_key: 'PostCode'
    attribute :country,                                :string
    attribute :zone,                                   :string
    attribute :currency_code,                          :string
    attribute :is_tax_registered,                      :boolean
    attribute :subscription_name,                      :string

    has_one :file_settings, FileSettings

    # Legacy find is FileIdentity?FileId=<id> returning a raw hash — wrap it here
    def self.find(file_id)
      from_wire(Saasu::FileIdentity.find(file_id))
    end

    # Legacy update is a bare PUT FileIdentity (no id in path); generic #save can't express it
    def self.update(params)
      Saasu::FileIdentity.update(params)
    end
  end
end
```

**Spec code** (`spec/saasi/deleted_entity_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::DeletedEntity do
  let(:wire) { { 'EntityType' => 'Sale', 'EntityId' => 33, 'DeletedByUser' => 'jack', 'Timestamp' => '2026-08-01T00:00:00Z', 'Novel' => 'kept' } }

  it 'round-trips losslessly' do
    expect(Saasi::DeletedEntity.from_wire(wire).to_wire).to eq wire
  end

  it 'validates entity type' do
    expect(Saasi::DeletedEntity.new(entity_type: 'Unicorn')).not_to be_valid
  end
end
```

**Spec code** (`spec/saasi/brand_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Brand do
  it 'round-trips with everything beyond id/name in extra' do
    wire = { 'Id' => 1, 'Name' => 'Main', 'LogoBytes' => 'xxx' }
    brand = Saasi::Brand.from_wire(wire)
    expect(brand.extra).to eq({ 'LogoBytes' => 'xxx' })
    expect(brand.to_wire).to eq wire
  end
end
```

**Spec code** (`spec/saasi/file_identity_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::FileIdentity do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'round-trips (PostCode wire key intact)' do
    wire = { 'Name' => 'My Biz', 'PostCode' => '2000', 'FileSettings' => { 'SaleAmountsIncludeTax' => true }, 'Novel' => 'kept' }
    expect(Saasi::FileIdentity.from_wire(wire).to_wire).to eq wire
  end

  it 'wraps the legacy query-param find' do
    # Faraday merges request params over the URL query string, so the final URL
    # carries a single FileId=888 (the argument wins over Config.file_id)
    stub_request(:get, 'https://api.saasu.com/FileIdentity?FileId=888').
      to_return(status: 200, body: { Name: 'Other Biz' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Saasi::FileIdentity.find(888).name).to eq 'Other Biz'
  end
end
```

If that exact stub fails because the runtime emits both FileId params, match with a block instead: `stub_request(:get, %r{https://api.saasu.com/FileIdentity}).with { |req| req.uri.query.split('&').include?('FileId=888') }` — assert the argument's value is present without assuming query normalisation.

**Commit messages:** `Add Saasi::DeletedEntity typed model`, `Add Saasi::Brand typed model`, `Add Saasi::FileIdentity typed model`

---

### Task 17: Saasi::InvoiceAttachment

**Files:** Create `lib/saasi/invoice_attachment.rb`, `spec/saasi/invoice_attachment_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/invoice_attachment.rb`):

```ruby
module Saasi
  class InvoiceAttachment < Saasi::Base
    wraps Saasu::InvoiceAttachment

    attribute :id,                   :integer
    attribute :name,                 :string
    attribute :description,          :string
    attribute :item_id_attached_to,  :integer
    attribute :size,                 :integer
    attribute :attachment_data,      :string  # base64 on the wire
    attribute :allow_existing_attachment_to_be_overwritten, :boolean

    read_only :size

    def self.for_invoice(invoice_id)
      Collection.new(Saasu::InvoiceAttachment.for_invoice(invoice_id).map { |a| from_wire(a.attributes) })
    end

    # Delegates to the legacy base64 upload helper; returns the insert envelope hash
    def self.upload(invoice_id, file, name: nil, description: nil, overwrite: false)
      Saasu::InvoiceAttachment.upload(invoice_id, file, name: name, description: description, overwrite: overwrite)
    end

    def decoded_data
      Base64.decode64(attachment_data) if attachment_data.present?
    end
  end
end
```

**Spec code** (`spec/saasi/invoice_attachment_spec.rb`):

```ruby
require 'spec_helper'
require 'base64'

describe Saasi::InvoiceAttachment do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'round-trips and decodes attachment data' do
    wire = { 'Id' => 9, 'Name' => 'inv.pdf', 'AttachmentData' => Base64.strict_encode64('PDF'), 'Novel' => 'kept' }
    attachment = Saasi::InvoiceAttachment.from_wire(wire)
    expect(attachment.decoded_data).to eq 'PDF'
    expect(attachment.to_wire).to eq wire
  end

  it 'lists typed attachments for an invoice' do
    stub_request(:get, 'https://api.saasu.com/InvoiceAttachments/33?FileId=777').
      to_return(status: 200, body: { Attachments: [{ Id: 9, Name: 'inv.pdf' }] }.to_json,
                headers: { 'Content-Type' => 'application/json' })

    attachments = Saasi::InvoiceAttachment.for_invoice(33)
    expect(attachments.first).to be_a(Saasi::InvoiceAttachment)
    expect(attachments.first.name).to eq 'inv.pdf'
  end
end
```

**Commit message:** `Add Saasi::InvoiceAttachment typed model with upload delegation`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 18: Saasi::User and Saasi::Search

**Files:** Create `lib/saasi/user.rb`, `lib/saasi/search.rb` and their two spec files; modify `lib/saasi.rb`. One commit per file.

**Class code** (`lib/saasi/user.rb`) — the legacy class is a bag of utility class methods; delegate verbatim (no typing gain available, kept for namespace completeness):

```ruby
module Saasi
  class User
    class << self
      def reset_password(username) = Saasu::User.reset_password(username)
      def current                  = Saasu::User.current
      def update(params)           = Saasu::User.update(params)
      def opt_in_to_2fa(params = {})      = Saasu::User.opt_in_to_2fa(params)
      def opt_out_from_2fa(params = {})   = Saasu::User.opt_out_from_2fa(params)
      def verify_2fa_opt_in(params = {})  = Saasu::User.verify_2fa_opt_in(params)
    end
  end
end
```

**Class code** (`lib/saasi/search.rb`) — same constructor contract as legacy, results typed as Saasi models:

```ruby
module Saasi
  class Search
    def initialize(keywords, params = {})
      @legacy = Saasu::Search.new(keywords, params)
    end

    def perform  = @legacy.perform
    def scope    = @legacy.scope
    def keywords = @legacy.keywords

    def contacts
      @legacy.contacts.map { |c| Saasi::Contact.from_wire(c.attributes) }
    end

    def invoices
      @legacy.invoices.map { |i| Saasi::Invoice.from_wire(i.attributes) }
    end

    def items
      @legacy.items.map { |i| Saasi::Item.from_wire(i.attributes) }
    end
  end
end
```

**Spec code** (`spec/saasi/user_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::User do
  it 'delegates reset_password to the legacy anonymous endpoint' do
    stub_request(:post, 'https://api.saasu.com/User/reset-password').
      with(body: { Username: 'user@saasu.com' }).
      to_return(status: 200, body: { StatusMessage: 'Sent' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Saasi::User.reset_password('user@saasu.com')).to eq 'Sent'
  end
end
```

**Spec code** (`spec/saasi/search_spec.rb`):

```ruby
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
```

Additionally in this task (spec requirement: utility modules are constant aliases): add to `lib/saasi.rb`, inside `module Saasi` (fine at load time — `lib/saasi.rb` is required by the LAST line of `lib/saasu.rb`, after the legacy modules exist):

```ruby
  LookupData = Saasu::LookupData
  Reports    = Saasu::Reports
```

with a spec appended to `spec/saasi/saasi_spec.rb`:

```ruby
  it 'aliases the raw-hash utility modules' do
    expect(Saasi::LookupData).to be Saasu::LookupData
    expect(Saasi::Reports).to be Saasu::Reports
  end
```

**Commit messages:** `Add Saasi::User delegation` and `Add Saasi::Search with typed results` (fold the utility aliases into the Search commit)

---

### Task 19: Saasi::Payroll (Employee, Entitlement, PayrollEntry, LeaveRequest, Timesheet, Payslip)

The .NET SDK contains NO payroll models (verified) — there is no authoritative field contract. These classes are therefore minimal: `id` typed, everything else through `extra`, CRUD delegated. Do not invent fields.

**Files:** Create `lib/saasi/payroll.rb`, `spec/saasi/payroll_spec.rb`; modify `lib/saasi.rb`.

**Class code** (`lib/saasi/payroll.rb`):

```ruby
module Saasi
  module Payroll
    class Employee < Saasi::Base
      wraps Saasu::Payroll::Employee
      attribute :id, :integer
    end

    class Entitlement < Saasi::Base
      wraps Saasu::Payroll::Entitlement
      attribute :id, :integer
    end

    class PayrollEntry < Saasi::Base
      wraps Saasu::Payroll::PayrollEntry
      attribute :id, :integer
    end

    class LeaveRequest < Saasi::Base
      wraps Saasu::Payroll::LeaveRequest
      attribute :id, :integer
    end

    class Timesheet < Saasi::Base
      wraps Saasu::Payroll::Timesheet
      attribute :id, :integer
    end

    class Payslip
      # PDF generation only; returns the raw PDF string
      def self.generate_pdf(id, template_id = nil)
        Saasu::Payroll::Payslip.generate_pdf(id, template_id)
      end
    end
  end
end
```

**Spec code** (`spec/saasi/payroll_spec.rb`):

```ruby
require 'spec_helper'

describe Saasi::Payroll do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'lists employees as typed models with fields in extra' do
    stub_request(:get, 'https://api.saasu.com/Payroll/Employees?FileId=777').
      to_return(status: 200, body: { Employees: [{ Id: 1, FirstName: 'Jack' }] }.to_json,
                headers: { 'Content-Type' => 'application/json' })

    employees = Saasi::Payroll::Employee.all
    expect(employees.first.id).to eq 1
    expect(employees.first.extra['FirstName']).to eq 'Jack'
  end

  it 'round-trips employee wire hashes' do
    wire = { 'Id' => 1, 'FirstName' => 'Jack' }
    expect(Saasi::Payroll::Employee.from_wire(wire).to_wire).to eq wire
  end
end
```

**Commit message:** `Add minimal Saasi::Payroll typed models (no .NET field contract exists)`

Execute THE STANDARD RESOURCE CYCLE with the above.

---

### Task 20: README — Saasi section and migration guide

**Files:** Modify `README.md`. No lib changes.

- [ ] **Step 1:** Add a `## Saasi — typed models` section to README.md after the existing Usage section, containing exactly:

````markdown
## Saasi — typed models

`Saasi` is the typed successor namespace to `Saasu` (and the gem's future
name). Every `Saasu::X` has a `Saasi::X` with snake_case typed attributes,
coercion, client-side validation, and lossless passthrough of API fields the
gem doesn't know yet (via `#extra`). Existing `Saasu::` code is unaffected —
migrate class by class.

```ruby
invoice = Saasi::Invoice.find(33)
invoice.transaction_date        # => #<Date 2026-08-06> (a real Date)
invoice.total_amount            # => BigDecimal("110.0")
invoice.line_items.first        # => #<Saasi::Invoice::LineItem>

invoice = Saasi::Invoice.new(
  invoice_type:     'Tax Invoice',
  transaction_type: 'S',
  layout:           'S',
  transaction_date: Date.today,
  line_items:       [{ description: 'Consulting', account_id: 123, total_amount: 100.0 }]
)
invoice.valid?                  # => true — checked before any HTTP
invoice.save                    # raises Saasi::ValidationError when invalid

Saasi::Invoice.new(transaction_typo: 'S')
# => ActiveModel::UnknownAttributeError — typos fail at the call site
```

### Migrating from Saasu::

| Legacy | Saasi |
|---|---|
| `Saasu::Invoice.find(33)['TransactionDate']` (string) | `Saasi::Invoice.find(33).transaction_date` (Date) |
| `invoice['LineItems']` (array of hashes) | `invoice.line_items` (typed models) |
| `Saasu::Config.configure { ... }` | `Saasi.configure { ... }` (same config) |
| `rescue RuntimeError` | `rescue Saasi::Error` (same classes, aliased) |
| server 400 on bad payload | `Saasi::ValidationError` before the request |

Behaviour differences to know:
- `save` validates first and raises `Saasi::ValidationError`; use `valid?` /
  `errors` to check without saving.
- `to_wire` omits nil fields — you cannot send an explicit JSON null through
  the typed layer; drop to `#extra` or the legacy class for that.
- API fields the gem doesn't declare are readable at `model.extra['TheField']`
  and survive save round-trips.
- Payroll models are untyped shells (the official SDK has no payroll
  contract); their fields live in `#extra`.
````

- [ ] **Step 2:** Run `bundle exec rspec` (green — README only).
- [ ] **Step 3:** Commit:

```bash
git add README.md
git commit -m "Document Saasi typed models and the Saasu -> Saasi migration path

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Appendix: Codex review adjudication (2026-08-06)

Codex (session 019fd6c5-7075-7c50-a0b4-1e1a83a4c1d2) reviewed this plan and returned 25 findings. Disposition:

**Accepted and applied** — #1 StringArrayType nil→[] (blocker; nil now stays nil); #2 delete leaves transaction_id (blocker; `clear_identity!`); #3 round-trip law vs read_only contradiction (blocker; law reworded to writable+undeclared keys); #7 refresh_from stale scalars (full attribute reset — this was a real bug: `send_email_to_contact` would have re-sent email on later updates); #8 extra/declared conflict (reject declared keys from extra copy); #9 fixture `presence: { on: }` mis-nesting (fixture simplified); #10 find nil-guard; #11 nested validation cascade (implemented — it delivers the feature's core promise); #12 FileIdentity.update delegation; #13 helper-method parity (Invoice email/generate_pdf/sales_stats_summary, Contact generate_pdf delegations added); #14 on: :create contradiction (blocker; resolved to UNCONDITIONAL presence — updates serialize the full payload, so required fields must be present in both contexts; spec doc amended); #16 DeletedEntity id; #19 long/byte type mapping; #22 ActiveModel floor raised to 6.1 (`errors.attribute_names`); #23 FileIdentity stub (Faraday param-merge documented + block-matcher fallback); #24 search fixture realism + extra-preservation assertions; #25 locale-independent error assertion. #15 partially: QuickPayment 2dp is a validation (parity with the legacy helper); amount-vs-invoice-total cross-check declined (server-side concern). #20 partially: a WebMock delegation test is now mandatory per resource (standard cycle); the full four-part matrix per resource declined as redundant with Base's suite. #6 partially: canonical datetime form narrowed to whole-second ISO8601; TimeWithZone handling declined (attributes cast to Time; TWZ can only enter via extra, which is untouched).

**Declined with rationale** — #4 wire_map/wraps inheritance hardening: resource-subclassing-resource is not a use case; constrained instead by convention ("resources subclass Saasi::Base directly"). #5 BigDecimal→to_f precision: parity with the legacy layer, which already operates on JSON-parsed floats; ActiveSupport would encode BigDecimal as a JSON *string* and change the wire contract; ceiling documented. #17 sent_to_contact read-only: the .NET source marks it neither [Required] nor read-only; the source of truth wins over inference. #18 owner_email writable vs names read-only: intentional — email is the assignment key, names are derived; rationale now commented in the task. #21 precision-hiding test values: subsumed by the #5/#6 canonical-form decisions.
