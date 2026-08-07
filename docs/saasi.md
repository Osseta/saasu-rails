# The `Saasi` Namespace (typed models)

`Saasi` is the typed successor to `Saasu` — and the gem's future name. Every
`Saasu::X` resource has a `Saasi::X` counterpart with snake_case typed
attributes, coercion, client-side validation, and typed nested objects.

Design promise: **`Saasi` does no HTTP of its own.** Every request delegates
to the corresponding `Saasu::` class, so both namespaces share one client, one
auth flow, one configuration, and identical wire behaviour. `Saasi` is a
typing layer, not a rewrite — which is what makes class-by-class
[migration](migration.md) safe.

## Reading

```ruby
invoice = Saasi::Invoice.find(1234)

invoice.transaction_date     # => #<Date 2026-08-06>          (:date coercion)
invoice.total_amount         # => BigDecimal("110.0")          (:decimal)
invoice.is_tax_inc           # => true                         (:boolean)
invoice.created_date_utc     # => Time (UTC)                   (:datetime)
invoice.tags                 # => ["consulting", "q3"]         (:string_array)

invoice.line_items           # => [Saasi::Invoice::LineItem, ...] — typed nested models
invoice.line_items.first.unit_price   # => BigDecimal
invoice.terms                # => Saasi::Invoice::Terms or nil
```

### Unknown fields never break you — `#extra`

Any wire field a model doesn't declare lands in `#extra` on read and is merged
back on write, losslessly. When Saasu adds a field tomorrow, your reads keep
working and your saves don't drop it:

```ruby
invoice.extra['BrandNewApiField']   # readable immediately, survives save round-trips
```

Assigning an *undeclared attribute* by name, however, raises — that's the typo
protection:

```ruby
Saasi::Invoice.new(transaction_typo: 'S')
# => ActiveModel::UnknownAttributeError
```

## Writing and validation

```ruby
invoice = Saasi::Invoice.new(
  invoice_type:     'Tax Invoice',
  transaction_type: 'S',
  layout:           'S',
  transaction_date: Date.today,                       # Date/Time accepted; serialized correctly
  line_items:       [{ description: 'Consulting',     # hashes coerce into typed nested models
                       account_id: 123, total_amount: 100.0 }]
)

invoice.valid?                 # => true/false — standard ActiveModel, no HTTP
invoice.errors.full_messages   # => ["Transaction date can't be blank", ...]

invoice.save                   # validates FIRST; raises Saasi::ValidationError before
                               # any HTTP if invalid; then delegates to the legacy class
invoice.update(summary: 'Q3 consulting')   # assign + save
invoice.delete                 # true/false; clears the model's identity on success
Saasi::Invoice.create(attrs)   # new + save
```

Validation rules are ported from the official .NET SDK's annotations:
required fields (`[Required]`) are unconditional presence validations; fields
with coded values validate inclusion against `Saasu::Constants` (always
`allow_nil`). **Nested models are validated too** — an invoice containing an
invalid `QuickPayment` fails `valid?` with the child's errors imported under
the association name.

`Saasi::ValidationError` carries the model:

```ruby
begin
  Saasi::Payment.create(transaction_date: Date.today)
rescue Saasi::ValidationError => e
  e.errors.attribute_names   # => [:transaction_type, :payment_account_id, :payment_items]
  e.model                    # the invalid instance
end
```

## Lists

```ruby
payments = Saasi::Payment.where(PaymentFromDate: '2026-07-01', PaymentToDate: '2026-07-31')
payments            # Saasi::Collection — an Array of typed models
payments.metadata   # envelope fields: paging, totals

# Filters are the SAME PascalCase filters as the legacy classes (they delegate
# to the same endpoints) — see the resource reference for each class's list.
```

## Serialization rules (`#to_wire`)

You rarely call `to_wire` yourself, but its rules explain save behaviour:

- Attributes serialize under their exact PascalCase wire keys; dates as
  `YYYY-MM-DD`, datetimes as ISO8601, decimals as JSON numbers.
- **nil attributes are omitted** — you cannot send an explicit JSON `null`
  through the typed layer. Use `#extra` or the legacy class for that (rare).
- `false` is a real value and is sent.
- **Read-only fields are never sent.** Server-derived fields
  (`CreatedDateUtc`, `PaymentStatus`, `StockOnHand`, contact display names,
  invoice `Attachments`, ...) are readable on fetched models but excluded
  from write payloads — the API owns them.
- `#extra` contents are merged in (declared attributes win on conflicts), with
  one exception: `_links` hypermedia is response-only and never sent back.

One trap to know: **list endpoints return summaries.** An invoice from
`.all`/`.where` has no `line_items`/`terms` (the API doesn't include them in
list responses) — re-`find` the record before mutating and saving it, or the
save will fail the `line_items` presence validation.

## Write-only fields (invoice)

`QuickPayment` and `SendEmailToContact`/`EmailMessage` are *write
instructions*: the API consumes them on create/update and never returns them
on GET. In `Saasi` they are normal assignable attributes with the constraints
enforced:

```ruby
invoice.quick_payment = { date_paid: Date.today, banked_to_account_id: 456, amount: 100.0 }
invoice.send_email_to_contact = true
invoice.email_message = { subject: 'Your invoice', body: 'Thanks!' }
invoice.save
```

- `QuickPayment` on an already-persisted invoice raises (the API accepts it on
  POST only), and its amount is validated to at most 2 decimal places.
- After `save`, the model refreshes from the API's response — so these fields
  reset to nil rather than going stale and accidentally re-firing on the next
  update.

## Resources with special shapes

- **`Saasi::Search`** — same constructor as the legacy search; `#contacts`,
  `#invoices`, `#items` return `Saasi`-typed results (search-specific display
  fields land in each result's `#extra`).
- **`Saasi::User`** — pure delegation of the six legacy class methods
  (`reset_password`, `current`, `update`, 2FA opt-in/out/verify).
- **`Saasi::FileIdentity`** — `find(file_id)` and `update(params)` follow the
  API's special shapes (query-param find; bare PUT update).
- **`Saasi::InvoiceAttachment`** — `for_invoice`, `upload` (delegates the
  Base64 helper), `#decoded_data`.
- **`Saasi::Payroll::*`** — fully typed from the live API docs: `Employee`
  (read-only, with `leave_balances`), `Entitlement`, `PayrollEntry`
  (`super_amount` maps the `Super` wire key), `LeaveRequest` (status enum,
  end-after-start and 63-day rules, items required when `Approved`,
  `LastModifiedDateUtc` as its concurrency token) and `Timesheet`. `Payslip`
  is a `generate_pdf` delegator taking a payroll-entry id.
- **`Saasi::LookupData` / `Saasi::Reports`** — constant aliases of the legacy
  raw-hash utility modules.
- **`Saasi::TaxCode`, `Saasi::Brand`, `Saasi::DeletedEntity`** — read-only
  resources; writes raise the legacy "not supported" error.

## Errors

`Saasi::Error` and `Saasi::NotFoundError` **are** the legacy classes
(constant aliases), so error handling is uniform across namespaces and
`rescue RuntimeError` still catches everything. `Saasi::ValidationError` is
the one addition, raised client-side before HTTP.

## Under the hood (for contributors)

`Saasi::Base` is ~220 lines: `ActiveModel::Model` + `ActiveModel::Attributes`,
a wire-key map (`attribute :x, :string, wire_key: 'X'` — auto-camelized by
default), `has_one`/`has_many` macros for nested value objects, `read_only`,
the `#extra` passthrough, and CRUD delegation via `wraps(Saasu::X)`. Two
invariants the test suite pins for every resource:

1. **Round-trip law:** `Model.from_wire(h).to_wire == h` for any wire hash of
   writable + undeclared keys in canonical wire form.
2. **Delegation:** each typed class hits exactly the legacy class's URLs
   (WebMock-verified).

The full design record lives in
`docs/superpowers/specs/2026-08-06-saasi-typed-models-design.md` and the
implementation plan (including the external codex review adjudication) in
`docs/superpowers/plans/2026-08-06-saasi-typed-models.md`.
