## Ruby Software Development Kit for Saasu API
This repository is a version of the Saasu software development kit in the Ruby language, for working with the Saasu API.
For help on the API itself, you can look at the [help documentation](https://api.saasu.com/).

[![Gem Version](https://badge.fury.io/rb/saasu2.svg)](http://badge.fury.io/rb/saasu2)
[![Build Status](https://travis-ci.org/nsinenko/saasu-rails.svg?branch=master)](https://travis-ci.org/nsinenko/saasu-rails)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'saasu2'
```

And then execute:

    $ bundle

Create an initializer file with your Saasu configuration eg config/initilizers/saasu.rb
```ruby
require 'saasu'

Saasu::Config.configure do |c|
  c.username = 'username@email.com'
  c.password = 'password'
  c.file_id = 1234 # Your Saasu FileId can be found at https://secure.saasu.com/a/net/webservicessettings.aspx
end
```

You're now ready to connect your app to Saasu.

## Usage

You can access the following objects:
- Saasu::Account
- Saasu::Company
- Saasu::Contact
- Saasu::Invoice
- Saasu::InvoiceAttachment
- Saasu::Item
- Saasu::Payment
- Saasu::TaxCode
- Saasu::Search
- Saasu::User
- Saasu::FileIdentity
- Saasu::ContactAggregate
- Saasu::Activity
- Saasu::Journal
- Saasu::ItemAdjustment
- Saasu::ItemTransfer
- Saasu::Brand
- Saasu::DeletedEntity
- Saasu::Payroll::Employee
- Saasu::Payroll::Entitlement
- Saasu::Payroll::PayrollEntry
- Saasu::Payroll::LeaveRequest
- Saasu::Payroll::Timesheet
- Saasu::Payroll::Payslip
- Saasu::LookupData (countries, currencies, date_formats, industry_types, number_formats, zones)
- Saasu::Reports (profit_and_loss_summary, profit_and_loss_summary_by_account_type)

Usage examples:

```ruby
# get all contacts
contacts = Saasu::Contact.all

# find a contact by id
contact = Saasu::Contact.find(123)

# save a contact
contact.given_name = 'New Name'
contact.save

# delete a contact
contact.delete

# create a contact
new_contact = Saasu::Contact.create({ GivenName => 'User' })

# filter records. for a list of available filters for each object see https://api.saasu.com
contact = Saasu::Contact.where(GivenName: 'John')

# get attributes
contact.id
contact['Id']

# set attributes
contact.given_name = 'Nick'
contact['GivenName'] = 'John'

# get all attributes
contact.attributes

# Search. Available scopes: All, Transactions, Contacts, InventoryItems. 
query = Saasu::Search.new('Book', 'InventoryItems')
query.perform

query.contacts
query.items
query.invoices

# You can filter search results by transaction type - Sale, Purchase, Journal, Payroll
query = Saasu::Search.new('Book', scope: 'InventoryItems', transaction_type: 'Sale')

# or you can use the default scope - 'All'
query = Saasu::Search.new('Book', transaction_type: 'Purchase')

# reset user password
Saasu::User.reset_password('user@saasu.com')

# list the set of files a user has access to
Saasu::FileIdentity.all
```

Note - Saasu uses .NET naming convention for fields and filters eg. GivenName, LastModifiedDate

### Advanced invoice options

An invoice create can carry a payment and/or send an email in the same API
call. Use the helpers — they validate the field names, required values and
date formats for you:

```ruby
invoice = Saasu::Invoice.new(
  'TransactionType' => 'S',
  'Layout'          => 'S',
  'TransactionDate' => '2026-08-06',
  'LineItems'       => [{ 'Description' => 'Consulting', 'AccountId' => 123, 'TotalAmount' => 100.0 }]
)

# record a payment in the same call instead of a separate Saasu::Payment
# (create-time only: the API accepts QuickPayment on POST, never on PUT)
invoice.add_quick_payment(date_paid: Date.today, banked_to_account_id: 456, amount: 100.0, reference: 'INV-1 payment')

# email the invoice to the billing contact as part of the save;
# with no arguments the API uses its default email template
invoice.email_on_save(subject: 'Your invoice', body: 'Thanks!')

invoice.save
```

The same fields can be set directly in the attributes hash
(`'QuickPayment' => { 'DatePaid' => ... }`, `'SendEmailToContact' => true`,
`'EmailMessage' => { ... }`) — attributes are passed through to the API as-is.
Note that neither field is returned on a GET.

To attach a file to an invoice use `Saasu::InvoiceAttachment.upload(invoice_id, file)`
— the `Attachments` field on the invoice payload itself is read-only.

An existing invoice can also be emailed after the fact with
`invoice.email` (to the billing contact) or `invoice.email('someone@example.com')`.

### Date filters

Pass dates to filters in `YYYY-MM-DD` format (e.g.
`Saasu::Invoice.where(InvoiceFromDate: '2026-01-01', InvoiceToDate: '2026-01-31')`).
It is the format the API documents for all date query args, and date-range
filters generally need both the `From` and `To` ends supplied together.

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
- Server-derived read-only fields (e.g. `CreatedDateUtc`, `PaymentStatus`) are
  readable on fetched models but never sent back on save — the API owns them.
- Payroll models are untyped shells (the official SDK has no payroll
  contract); their fields live in `#extra`.

## Contributing

1. Fork it ( https://github.com/saasu/saasu2-ruby/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
