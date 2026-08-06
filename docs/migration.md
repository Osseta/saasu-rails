# Migrating from `Saasu::` to `Saasi::`

Both namespaces ship in this gem and share one HTTP client, so migration is
**class-by-class and risk-free to stage**: migrate `Invoice` today and leave
`Contact` on the legacy API for a year, and nothing conflicts. Existing
`Saasu::` code needs no changes, ever — see the
[compatibility guarantees](saasu-legacy.md#backwards-compatibility-guarantees).

## Why migrate

| Pain on `Saasu::` | On `Saasi::` |
|---|---|
| `invoice['TransactionDate']` returns a string | `invoice.transaction_date` returns a `Date` |
| A typoed hash key is silently ignored by the server | `ActiveModel::UnknownAttributeError` at the call site |
| A missing required field costs an HTTP 400 round-trip | `Saasi::ValidationError` before any HTTP, with `errors` |
| Line items are raw hash arrays | Typed nested models with their own coercion/validation |
| PascalCase string keys everywhere | snake_case Ruby attributes |

## The translation table

| Legacy | Saasi |
|---|---|
| `Saasu::Invoice.find(33)['TransactionDate']` | `Saasi::Invoice.find(33).transaction_date` |
| `invoice['LineItems']` (hashes) | `invoice.line_items` (typed models) |
| `invoice['GivenName'] = 'x'` / `invoice.given_name = 'x'` | `invoice.given_name = 'x'` (unknown names raise) |
| `Saasu::Contact.where(GivenName: 'John')` | `Saasi::Contact.where(GivenName: 'John')` — filters unchanged |
| `collection.metadata` | `collection.metadata` — unchanged |
| `Saasu::Config.configure { ... }` | `Saasi.configure { ... }` (same config object) |
| `rescue Saasu::Error` / `rescue RuntimeError` | `rescue Saasi::Error` — same classes, aliased |
| server 400 on a bad payload | `Saasi::ValidationError` before the request |
| `invoice.add_quick_payment(...)` helper | `invoice.quick_payment = { date_paid: ..., ... }` |
| `invoice.email_on_save(subject: ...)` helper | `invoice.send_email_to_contact = true; invoice.email_message = { subject: ... }` |
| `Saasu::InvoiceAttachment.upload(...)` | `Saasi::InvoiceAttachment.upload(...)` — same signature |
| `Saasu::Search.new(...).contacts` → legacy objects | `Saasi::Search.new(...).contacts` → typed objects |

## Behaviour differences to plan for

These are the only ways a migrated class behaves differently:

1. **`save` validates first** and raises `Saasi::ValidationError` when the
   model is invalid — the legacy class would have sent the request and let the
   server 400. Use `valid?`/`errors` to check without saving. If you relied on
   the server accepting a payload the local validations reject, that's worth a
   look — but `#extra` is the pressure valve (see 4).
2. **nil means "omit".** `to_wire` drops nil attributes, so you cannot send an
   explicit JSON `null` to clear a field through typed attributes. Drop to the
   legacy class or write into `#extra` for that rare case.
3. **Read-only fields are not sent back.** Server-derived fields
   (`CreatedDateUtc`, `PaymentStatus`, display names, ...) are readable but
   excluded from write payloads. The legacy class sent them back verbatim (the
   server ignored them) — if you were *depending* on echoing one, you weren't.
4. **Unknown attribute names raise on assignment** (`new`, `assign_attributes`,
   setters). Unknown *wire fields from the API* never raise — they flow into
   `#extra` and survive save round-trips. To write a field the model doesn't
   declare yet: `model.extra['NewField'] = value`.
5. **Payroll models are untyped shells** (no official field contract exists):
   read fields via `employee.extra['FirstName']`.

## A worked migration

Before:

```ruby
invoice = Saasu::Invoice.find(inv_id)
if Date.parse(invoice['TransactionDate']) < 30.days.ago.to_date && invoice['PaymentStatus'] == 'U'
  invoice['Tags'] = (invoice['Tags'] || []) + ['overdue']
  invoice.save
end
```

After:

```ruby
invoice = Saasi::Invoice.find(inv_id)
if invoice.transaction_date < 30.days.ago.to_date && invoice.payment_status == 'U'
  invoice.tags += ['overdue']
  invoice.save
end
```

## Suggested order

1. Start with the resource where typing pays off most for you — usually
   `Invoice` (dates, decimals, nested line items) or `Payment`.
2. Migrate read paths first (`find`/`where` + attribute reads) — zero
   behavioural risk.
3. Migrate write paths, adding a `rescue Saasi::ValidationError` where you
   want friendly handling; the validation catches what previously came back
   as a 400.
4. Leave utility calls (`LookupData`, `Reports`, PDFs) for last or forever —
   they're identical in both namespaces.

## The road to the `saasi` gem

The plan of record: this gem (`saasu2`) ships both namespaces during the
migration era. A future release will be published under the gem name `saasi`
(verified available), with `Saasu::` retained as a deprecated compatibility
shim before eventual removal in a major version. No date is set; nothing
about the timeline changes the guidance above — code you migrate now is
already written against the surviving API.
