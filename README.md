# Saasu API — Ruby SDK

A Ruby client for the [Saasu](https://www.saasu.com/) accounting API, shipping
two namespaces in one gem:

- **`Saasu`** — the original hash-based client. Stable, fully supported, and
  guaranteed backwards compatible: existing apps keep working unchanged.
- **`Saasi`** — the typed successor (and the gem's future name): snake_case
  typed attributes, coercion, client-side validation, typed nested objects.
  Recommended for new code.

Both share one HTTP client, one configuration, and one authentication flow —
`Saasi` delegates every request to the `Saasu` classes underneath, so you can
migrate class by class with zero risk of the two layers disagreeing.

[![Gem Version](https://badge.fury.io/rb/saasu2.svg)](http://badge.fury.io/rb/saasu2)
[![Build Status](https://travis-ci.org/nsinenko/saasu-rails.svg?branch=master)](https://travis-ci.org/nsinenko/saasu-rails)

## Installation

```ruby
# Gemfile
gem 'saasu2'
```

Then configure once (e.g. `config/initializers/saasu.rb`):

```ruby
require 'saasu'

Saasu::Config.configure do |c|
  c.username = 'username@email.com'
  c.password = 'password'
  c.file_id  = 1234  # https://secure.saasu.com/a/net/webservicessettings.aspx
end
```

Authentication is automatic — the client obtains, caches, and refreshes its
OAuth token transparently on first use. All configuration options (OAuth
scope, 2FA, API URL override) are covered in
[Getting started](docs/getting-started.md).

## Quick start — `Saasi` (typed, recommended)

```ruby
invoice = Saasi::Invoice.find(1234)
invoice.transaction_date          # => #<Date 2026-08-06> — a real Date
invoice.total_amount              # => BigDecimal("110.0")
invoice.line_items.first          # => #<Saasi::Invoice::LineItem> — typed nested models
invoice.extra['BrandNewApiField'] # fields the gem doesn't know yet are still readable

invoice = Saasi::Invoice.new(
  invoice_type:     'Tax Invoice',
  transaction_type: 'S',
  layout:           'S',
  transaction_date: Date.today,
  line_items:       [{ description: 'Consulting', account_id: 123, total_amount: 100.0 }]
)
invoice.valid?      # => true — checked locally, before any HTTP
invoice.save        # raises Saasi::ValidationError (with .errors) when invalid

Saasi::Invoice.new(transaction_typo: 'S')
# => ActiveModel::UnknownAttributeError — typos fail at the call site,
#    not silently on the server

contacts = Saasi::Contact.where(IsCustomer: true, Page: 1, PageSize: 25)
contacts.metadata   # paging/total fields from the response envelope
```

## Quick start — `Saasu` (hash-based, legacy)

```ruby
contact = Saasu::Contact.find(123)
contact['GivenName']              # raw API hash, PascalCase keys
contact.given_name = 'Nick'       # generated snake_case accessors
contact.save

Saasu::Contact.where(GivenName: 'John')      # validated filter names
Saasu::Contact.create('GivenName' => 'User')

# every attribute passes through as-is — anything the API accepts works
invoice = Saasu::Invoice.new('TransactionType' => 'S', 'Layout' => 'S',
                             'TransactionDate' => '2026-08-06',
                             'LineItems' => [{ 'Description' => 'Consulting',
                                               'AccountId' => 123, 'TotalAmount' => 100.0 }])
invoice.add_quick_payment(date_paid: Date.today, banked_to_account_id: 456, amount: 100.0)
invoice.email_on_save(subject: 'Your invoice', body: 'Thanks!')
invoice.save
```

## Which namespace should I use?

| | Use `Saasi` | Use `Saasu` |
|---|---|---|
| New code | ✅ | |
| Existing code | migrate class by class when convenient ([guide](docs/migration.md)) | ✅ keeps working unchanged, indefinitely |
| Need typed values, validation, typo safety | ✅ | |
| Need to send an explicit JSON `null`, or bug-for-bug wire parity | | ✅ (or `Saasi`'s `#extra` escape hatch) |

## What's covered

Every Saasu API resource, in both namespaces: accounts (+ bank balances),
activities, brands, companies, contacts (+ PDF), contact aggregates, deleted
entities (sync feed), file identities, invoices (+ email, PDF, quick payment,
attachments, sales stats), inventory items (+ combo builds), item
adjustments/transfers, journals, payments, tax codes, search, users (+ 2FA,
anonymous password reset), payroll (employees, entitlements, entries, leave,
timesheets, payslip PDFs), lookup data, and P&L reports. The full
per-resource operation and filter tables are in the
[resource reference](docs/resources.md).

## Error handling

```ruby
begin
  Saasi::Invoice.find(999_999)
rescue Saasi::NotFoundError          # 404
rescue Saasi::Error => e             # any other non-2xx
  e.status                           # => 400
  e.body                             # => parsed API error body
end
```

`Saasi::Error`/`Saasu::Error` are the same classes and subclass
`RuntimeError`, so legacy rescue code keeps working. `Saasi` additionally
raises `Saasi::ValidationError` client-side, before any HTTP, when a model
fails validation.

## Documentation

| Guide | What's in it |
|---|---|
| [Getting started](docs/getting-started.md) | Install, configuration, authentication, first requests |
| [The Saasi namespace](docs/saasi.md) | Typed models: coercion, validation, nested objects, `#extra`, serialization rules |
| [The Saasu namespace](docs/saasu-legacy.md) | The hash API, special operations, wire vocabularies, **backwards-compatibility guarantees** |
| [Migration guide](docs/migration.md) | `Saasu::` → `Saasi::` translation table, behaviour differences, staged strategy |
| [Resource reference](docs/resources.md) | Every resource: operations, filters, special methods |
| [Model relationships](docs/models.md) | Entity-relationship diagram |

Field and filter names follow the API's .NET naming convention
(`GivenName`, `LastModifiedFromDate`); `Saasi` exposes them as snake_case
attributes. Dates in filters are `YYYY-MM-DD` strings, and date ranges
generally need both the `From` and `To` ends supplied together.

## Requirements

- Ruby 3.x
- ActiveModel >= 6.1 (installed as a gem dependency)

## Contributing

1. Fork it ( https://github.com/saasu/saasu2-ruby/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
