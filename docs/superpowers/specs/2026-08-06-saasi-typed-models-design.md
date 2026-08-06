# Saasi — Typed Models Namespace: Design Spec

Date: 2026-08-06
Status: approved by Anthony (conversation, 2026-08-06)

## Goal

A new top-level `Saasi` namespace of fully typed models for every Saasu
resource, wrapping the existing `Saasu::` classes so existing applications
work unchanged. `Saasi` is the future gem name (verified unpublished on
rubygems.org 2026-08-06; `sai` and `saasu` are taken). Apps migrate class by
class from `Saasu::X` to `Saasi::X` to gain type coercion, typo protection,
and client-side validation.

## Decisions (settled with the user)

| Decision | Choice |
|---|---|
| Validation/attribute engine | ActiveModel (`ActiveModel::Model` + `ActiveModel::Attributes`) |
| Namespace / future gem name | `Saasi` / `saasi` |
| Scope | Every resource, staged core-first |
| Migration strategy | Saasi wraps Saasu; both namespaces ship in the `saasu2` gem for now; gem rename is a later, out-of-scope step |

## Non-goals

- No new HTTP code: `Saasi` rides entirely on `Saasu::Client`, `Saasu::Auth`,
  `Saasu::Config`.
- No changes to any `Saasu::` class behaviour.
- No gem rename/publication in this effort.
- No typed wrappers for the raw-hash utility modules — `Saasi::LookupData`,
  `Saasi::Reports` are constant aliases of the legacy modules.
- Explicit JSON `null` cannot be sent through the typed layer (nil attributes
  are omitted from payloads); users needing that use `#extra` or the legacy class.

## Architecture

```
Saasi::Invoice  --wraps-->  Saasu::Invoice  --uses-->  Saasu::Client (HTTP)
     |                            |
 typed attrs,                raw hash attrs,
 valid?/errors               unchanged behaviour
```

- Class methods `find` / `all` / `where` / `create` delegate to the legacy
  class and wrap results into typed models.
- `#save` / `#delete` serialize typed attributes to the PascalCase wire hash,
  hand it to a legacy instance, delegate, then refresh the typed model from
  the legacy instance's post-save attributes.
- `.all`/`.where` return `Saasi::Collection` — an Array of typed models with
  the same `#metadata` as `Saasu::Collection`.

## File layout

```
lib/saasi.rb                 # requires activemodel + all saasi files
lib/saasi/base.rb            # Saasi::Base + DSL (wire mapping, has_one/has_many, extra)
lib/saasi/collection.rb      # Saasi::Collection < Array, #metadata
lib/saasi/errors.rb          # Saasi::ValidationError; Saasi::Error/NotFoundError aliases
lib/saasi/invoice.rb         # Saasi::Invoice + nested LineItem, QuickPayment, EmailMessage, Terms
lib/saasi/contact.rb         # ... one file per resource; nested value objects live
lib/saasi/payment.rb         #     in their parent resource's file
...
lib/saasi/payroll.rb         # Saasi::Payroll::* (six classes, one file, mirrors legacy)
spec/saasi/<file>_spec.rb    # one spec file per lib/saasi file (project convention)
```

`lib/saasu.rb` gains `require "saasi"` as its last require, so
`require 'saasu'` keeps working and exposes both namespaces. `lib/saasi.rb`
does not require `saasu` (avoids the cycle; the gem's entry point is saasu).

Dependency: `saasu2.gemspec` adds `spec.add_dependency 'activemodel', '>= 6.0'`.
This also (transitively) fixes the existing undeclared-activesupport bug.
Remove the incorrect `webmock` runtime dependency from the gemspec if present
(it belongs in development dependencies) — pre-existing defect, one line,
same gemspec edit.

## Saasi::Base — the DSL

```ruby
class Saasi::Invoice < Saasi::Base
  wraps Saasu::Invoice

  attribute :transaction_type, :string           # wire key auto-derived: 'TransactionType'
  attribute :transaction_date, :date
  attribute :amount_paid,      :decimal
  attribute :is_active,        :boolean, wire_key: 'IsActive'  # override available; rarely needed

  has_many :line_items,    LineItem                            # wire: 'LineItems'
  has_one  :quick_payment, QuickPayment                        # wire: 'QuickPayment'

  validates :transaction_type, inclusion: { in: Saasu::Constants::INVOICE_TRANSACTION_TYPES.values }, allow_nil: true
  validates :line_items, presence: true, on: :create
end
```

Mechanics:

- `wraps(klass)` stores the legacy class used for all HTTP delegation.
- `attribute` wraps `ActiveModel::Attributes#attribute`; registers
  `wire_key || name.to_s.camelize` in a class-level wire map (inherited).
- `has_one(name, klass, wire_key: nil)` / `has_many(...)`: define
  reader/writer that coerce hashes (and arrays of hashes) into nested
  `Saasi::Base` value objects; serialize via the nested object's `#to_wire`.
- **`#extra` (Hash)**: every wire key not in the wire map lands here on read
  and is merged back on write. Reads can never break and data never drops
  when Saasu adds fields. Assigning an undeclared attribute raises
  `NoMethodError` (the typo protection).
- `.from_wire(hash)` — build typed instance from an API hash (attributes via
  wire map with ActiveModel coercion; leftovers to `#extra`).
- `#to_wire` — PascalCase hash of non-nil attributes (dates as `YYYY-MM-DD`,
  datetimes as ISO8601, decimals as numerics) + serialized nested models +
  `extra` merged (declared attributes win on key conflict).
- `#id` — every resource declares `attribute :id, :integer` (wire `'Id'`);
  transaction resources also declare `transaction_id`, and `#id` falls back
  to it when `id` is nil, matching `Saasu::Base#id`.

Round-trip law (property every model spec asserts):
`Model.from_wire(h).to_wire == h` for any wire hash `h` whose values are
already in canonical wire form, including undeclared keys.

## CRUD semantics

| Method | Behaviour |
|---|---|
| `.find(id)` | `from_wire(legacy.find(id).attributes)`; `Saasu::NotFoundError` propagates |
| `.all` / `.where(filters)` | delegate to legacy (filters unchanged, PascalCase); map records through `from_wire`; wrap in `Saasi::Collection` with the legacy collection's `metadata` |
| `.create(attrs)` | `new(attrs)` → `save` → returns the model |
| `#save` | `validate!` → raise `Saasi::ValidationError` (carries `#model`, `#errors`) if invalid → build legacy instance from `to_wire` → legacy `save` → `refresh_from(legacy.attributes)` → `true` |
| `#delete` | delegates to legacy instance `#delete`; clears local id on success |

Validation contexts: `on: :create` validations run when the model has no id.
`valid?` / `errors` usable standalone. Server-side errors are untouched
(`Saasi::Error = Saasu::Error`, `Saasi::NotFoundError = Saasu::NotFoundError`).

`Saasi.configure` is an alias for `Saasu::Config.configure` (same underlying
config; documented so migrated apps need no `Saasu` reference).

## Field definitions — source of truth

Extract per resource from the .NET SDK (`tmp/api-sdk-dotnet-master/Saasu.API.Core/Models/**`):
field names, types, `[Required]` annotations, and doc-comment constraints.

Type mapping rules:

| .NET | Saasi attribute type |
|---|---|
| `string` | `:string` |
| `int` / `short` | `:integer` |
| `decimal` | `:decimal` |
| `bool` | `:boolean` |
| `DateTime` named `*Utc`, `LastModified*`, `Timestamp` | `:datetime` |
| other `DateTime` (business dates) | `:date` |
| nested model / `List<T>` | `has_one` / `has_many` |
| `List<string>` (Tags) | `attribute :tags, array-of-string` (custom type in Base, one implementation) |

Enum-valued strings get `inclusion` validations from `Saasu::Constants`
(always `allow_nil: true`; the server owns required-ness except where the
.NET `[Required]` annotation says otherwise, which becomes `presence` with
the matching `on:` context).

Write-only fields (never returned on GET — from .NET doc comments):
`Invoice#quick_payment`, `Invoice#email_message` / `#send_email_to_contact`.
Modelled as normal assignable attributes, serialized on create, with doc
comments stating they are write instructions (`QuickPayment` additionally
raises on save when the model is persisted, matching the legacy helper).
The read-only `Attachments` field on Invoice is exposed as a reader populated
from GET but excluded from `#to_wire`.

## Testing

- One spec file per lib file under `spec/saasi/`.
- Per resource: (1) round-trip law spec including undeclared-key preservation,
  (2) coercion spec (string date in → Date out, etc.), (3) validation spec
  (required/enum/context), (4) one WebMock CRUD spec proving delegation hits
  the same URLs as the legacy class.
- `Saasi::Base` gets the deep unit suite (wire map, has_one/has_many, extra,
  to_wire nil-omission, ValidationError); resource specs stay thin.

## Staging (each stage = one or more small commits, suite green at each)

1. **Infrastructure**: gemspec dependency, `Saasi::Base` + DSL, `Collection`,
   errors, `Saasi.configure`, `lib/saasi.rb` wiring, Base spec suite.
2. **Invoice** (+ LineItem, QuickPayment, EmailMessage, Terms nested models) —
   proves the pattern on the hardest resource.
3. **Contact, Payment (+ PaymentItem), Item (+ BuildItem)**.
4. **Account, Company, Journal (+ JournalItem), TaxCode, Activity,
   ItemAdjustment (+ AdjustmentItem), ItemTransfer (+ TransferItem)**.
5. **ContactAggregate (+ Company/ContactManager nested), DeletedEntity,
   FileIdentity, InvoiceAttachment, Brand, User, Search** (Search returns
   Saasi-typed results; User/Search follow their legacy non-CRUD shapes).
6. **Payroll::*** (Employee, Entitlement, PayrollEntry, LeaveRequest,
   Timesheet, Payslip).
7. **README**: Saasi usage section + migration guide (`Saasu::X` → `Saasi::X`
   table, behaviour differences, escape hatches).

Stages 2–6 are mechanical repetitions of the stage-2 pattern and are the
delegation targets for cheaper-model subagents; stage 1 sets the contract.

## Risks / mitigations

- **ActiveModel version spread** (6.x–8.x API drift in Attributes): pin
  `>= 6.0`; Base uses only the stable public API (`attribute`, types,
  validations). CI is a later concern; local suite runs against the installed
  version.
- **.NET model inaccuracies** (already caught one: read-only Attachments):
  every resource's WebMock spec asserts real wire shapes; doc comments are
  trusted over test-helper behaviour.
- **Name/constant collisions in nested models** (e.g. two resources with
  `Company` nests): nested value objects are namespaced under their parent
  class (`Saasi::ContactAggregate::Company`), never top-level.
