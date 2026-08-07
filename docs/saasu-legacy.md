# The `Saasu` Namespace (legacy, stable)

`Saasu::` is the original hash-based client. It is **stable and fully
supported**: the `Saasi` typed layer is built on top of it, not instead of it,
and every `Saasi` request passes through these classes. If you have existing
code on `Saasu::`, nothing changes for you.

## Backwards-compatibility guarantees

These hold across gem releases until a major version says otherwise:

1. **The hash API is permanent.** `Saasu::` classes store and return raw,
   string-keyed attribute hashes exactly as the API sends them. Fields the gem
   has never heard of pass straight through in both directions — a Saasu API
   addition can never break you or be dropped from your payloads.
2. **Error classes subclass `RuntimeError`.** `Saasu::Error` (carrying
   `#status` and `#body`) and `Saasu::NotFoundError` were introduced without
   breaking `rescue RuntimeError` callers, and their messages kept the
   original wording (`"Resource not found."` etc.).
3. **List results are Arrays.** `.all`/`.where` return `Saasu::Collection`,
   an `Array` subclass — every Array operation works as before. The addition
   is `#metadata`: the response envelope's non-collection fields (paging,
   totals).
4. **All 2xx statuses are success.** (Historically only 200 was; 201/204 from
   creates and deletes no longer raise.)
5. **`Saasi` never modifies `Saasu`.** Adding the typed layer touched the
   legacy code in exactly two places: the gemspec (new `activemodel`
   dependency) and one `require "saasi"` line at the end of `lib/saasu.rb`.

## Scope of the client (deliberate limitations)

- **JSON only.** The API also speaks XML (via the `Content-Type` header); the
  gem doesn't and won't.
- **OAuth only.** The API still accepts the legacy `wsAccessKey=...&FileId=...`
  query-string credentials ("will be phased out" per the docs); the gem
  supports only the OAuth password grant.
- **Version pinned.** Every request sends `X-Api-Version: 1.0` (the current
  version). Omitting it would mean "latest"; the API keeps at most two prior
  versions and signals deprecated calls via `rel: "deprecated"` hypermedia links.
- **No rate-limit handling.** Saasu applies per-plan "Fair Play" limits (see
  https://www.saasu.com/system-requirements/); the gem surfaces whatever the
  server returns via `Saasu::Error` and does not retry.
- **Hypermedia `_links`** blocks in responses are preserved for reading
  (`collection.metadata['_links']`, `record['_links']`) but are stripped from
  write payloads, as the API requires.
- **Deprecated API fields** you shouldn't build on: `Company.LogoUrl`,
  `Account.IncludePendingTransactions`, `FileIdentity.FileSettings` and the
  `DateTimeFormatId`/`NumberFormatId` pairs (FileIdentity and User), the
  `Invoice.InvoiceStatus` field (the filter remains valid), and the
  `LookupData` DateFormats/NumberFormats endpoints.

## The CRUD surface

Every resource class inherits the same surface from `Saasu::Base` (only the
operations the API supports are enabled per class — see the
[resource reference](resources.md)):

```ruby
Saasu::Contact.all                         # => Saasu::Collection of Saasu::Contact
Saasu::Contact.all.metadata                # => { "TotalRecords" => 42, ... } (envelope fields)
Saasu::Contact.where(GivenName: 'John')    # filtered; filter NAMES are validated locally
Saasu::Contact.find(123)                   # => Saasu::Contact (raises Saasu::NotFoundError on 404)
Saasu::Contact.create(GivenName: 'User')   # POST, then re-fetches the created record

contact = Saasu::Contact.find(123)
contact['GivenName']                       # hash access — the canonical form
contact.given_name                         # generated snake_case reader
contact.given_name = 'Nick'                # generated writer (writes the 'GivenName' key)
contact['Tags'] = ['vip']                  # any key can be set directly
contact.save                               # PUT (record has an Id) or POST, then re-fetch
contact.update('GivenName' => 'Jack')      # merge + save
contact.delete                             # DELETE; true/false, clears the Id on success
```

Notes and sharp edges:

- **Field casing:** the API uses .NET PascalCase (`GivenName`,
  `LastModifiedDate`). Hash keys must match exactly. The generated
  snake_case accessors camelize back (`given_name` ⇄ `GivenName`).
- **Unknown filters raise locally** with the supported list, e.g.
  `Saasu::Contact.where(Nope: 1)` →
  `"Filter not supported by Saasu API: Nope. Supported filters: ..."`.
  Filter *values* are not validated — see `Saasu::Constants` below for the
  legal wire values.
- **Dates in filters:** use `YYYY-MM-DD` strings. Date-range filters
  (`*FromDate`/`*ToDate`) must be supplied as pairs — the API documents each
  end as requiring the other, on every list endpoint.
- **Paging:** pass `Page:` and `PageSize:` to `.where`. `PageSize` defaults to
  **25** and maxes at **100**, so `.all` returns the first 25 records, not
  everything; page metadata is on `collection.metadata`. No paging exists on
  Brands, BankAccountBalances, LookupData, Reports, or Payroll
  Employees/Entitlements.
- **Silent default windows:** `Payments` defaults to the **last month** when
  no `PaymentFromDate`/`PaymentToDate` is given (and ignores `TransactionType`
  when `ForInvoiceId` is supplied); `DeletedEntities` defaults to the
  **last 24 hours** — a sync loop must pass explicit `UtcDeleted*` bounds.
- **Concurrency:** responses carry `LastUpdatedId`; the API requires it on
  subsequent updates to detect conflicting edits. The gem's save-then-refetch
  flow keeps it current automatically — just don't strip it from attribute
  hashes you build by hand.
- **`SearchText` max 128 characters** (Items and Activities filters).
- **`IsTaxInc` defaults to `false`** when omitted on invoice insert/update —
  tax-inclusive amounts must set it explicitly.

## Special operations

Beyond CRUD, the legacy classes expose every extra endpoint the API has:

```ruby
# Invoices
invoice.email                                # POST Invoice/:id/email-contact (billing contact)
invoice.email('someone@example.com')         # POST Invoice/:id/email with EmailTo
invoice.generate_pdf(template_id = nil)      # => raw PDF bytes in a String
Saasu::Invoice.sales_stats_summary(params)   # GET Invoices/SalesStatsSummary

# Create-time write instructions (validated keyword helpers)
invoice.add_quick_payment(date_paid:, banked_to_account_id:, amount:,
                          date_cleared: nil, reference: nil, summary: nil)
invoice.email_on_save(subject: nil, body: nil, from: nil, to: nil, cc: nil, bcc: nil)

# Attachments (the invoice payload's own Attachments field is READ-ONLY —
# uploads must use this endpoint)
Saasu::InvoiceAttachment.upload(invoice_id, file_or_path, name: nil, description: nil, overwrite: false)
Saasu::InvoiceAttachment.for_invoice(invoice_id)   # list
attachment.decoded_data                            # Base64-decoded file content

# Items
item.build('Quantity' => 5)                        # assemble a combo item

# Contacts — statement PDF (the only documented GenerateType; date range required)
contact.generate_pdf(from_date: '2026-07-01', to_date: '2026-07-31')

# Accounts
Saasu::Account.bank_account_balances(params = {})

# Search (Saasu "Jump")
query = Saasu::Search.new('Book', scope: 'InventoryItems',      # All | Transactions | Contacts | InventoryItems
                          transaction_type: 'Sale',             # Sale | Purchase | Journal | Payroll
                          page: 2, page_size: 50,
                          include_search_term_highlights: false)
query.perform      # => { contacts: 8, invoices: 10, items: 15 } (totals)
query.contacts     # => [Saasu::Contact, ...]
query.invoices     # => [Saasu::Invoice, ...]
query.items        # => [Saasu::Item, ...]

# Users (reset_password is anonymous — works without credentials)
Saasu::User.reset_password('user@saasu.com')
Saasu::User.current
Saasu::User.update(params)
Saasu::User.opt_in_to_2fa / opt_out_from_2fa / verify_2fa_opt_in

# Files, lookups, reports
Saasu::FileIdentity.all                      # files your login can access
Saasu::FileIdentity.find(file_id)
Saasu::LookupData.countries / currencies / date_formats / industry_types / number_formats / zones
Saasu::Reports.profit_and_loss_summary(params)
Saasu::Reports.profit_and_loss_summary_by_account_type(params)

# Payroll
Saasu::Payroll::Employee.all
Saasu::Payroll::PayrollEntry.where(FromDate: '2026-07-01', ToDate: '2026-07-31')
Saasu::Payroll::Payslip.generate_pdf(id, template_id = nil)
```

## Wire vocabularies — `Saasu::Constants`

The API expects specific coded values in several fields and filters. They are
all collected (ported from the official .NET SDK) in `Saasu::Constants`:

| Constant | Values |
|---|---|
| `INVOICE_STATUSES` | `invoice: 'I', quote: 'Q', order: 'O'` |
| `PAYMENT_STATUSES` | `paid: 'P', unpaid: 'U', all: 'A'` |
| `INVOICE_TRANSACTION_TYPES` | `sale: 'S', purchase: 'P'` |
| `PAYMENT_TRANSACTION_TYPES` | `sale_payment: 'SP', purchase_payment: 'PP'` |
| `TAG_SELECTIONS` | `requireAll requireAny excludeAll excludeAny` |
| `ACCOUNT_TYPES` | `Income, Expense, Asset, Equity, Liability, Other Income, Other Expense, Cost of Sales` |
| `ITEM_TYPES` | `inventory: 'I', combo: 'C'` |
| `SEARCH_METHODS` | `Contains, StartsWith` (SearchText max 128 chars, required together) |
| `ACTIVITY_STATUSES` | `todo, done, overdue` |
| `ATTACHED_TO_TYPES` | `Contact, Employee, Sale, Purchase` |
| `DELETED_ENTITY_TYPES` | `Sale, Purchase, SalePayment, PurchasePayment, Item, Contact, Journal` |
| `SEARCH_SCOPES` / `SEARCH_TRANSACTION_TYPES` | see search above |
| `OAUTH_SCOPES` | `view, modify, delete, full, fileid` (`fileid:1234` form) |
| `INVOICE_LAYOUTS` | `item: 'I', service: 'S'` (+ SDK-only `purchase: 'P'`) |
| `INVOICE_TYPES` | 9 documented values (`Tax Invoice`, `Quote`, ...) + 7 SDK-only legacy values |
| `INVOICE_TERMS_TYPES` / `INVOICE_TERMS_INTERVAL_TYPES` | trading-terms enums (`DueIn`, `Week`, ...) |
| `PRINT_AS` | invoice PDF layouts: sale `4/93/99/98`, purchase `7/95/100` |
| `FOR_ENTITY_TYPES` | invoice `ForEntityTypeId`: `sale: 4, shipping_slip: 98` |
| `ACCOUNT_TYPE_FILTERS` / `ACCOUNT_LEVEL_FILTERS` | filter forms (`OtherIncome`, `detail`) — differ from the body-field forms |
| `ACCOUNTING_METHODS` | `Accrual, Cash` (Reports) |
| `LEAVE_REQUEST_STATUSES` | `Pending, Approved, Rejected` |
| `TAX_CODES` | BAS codes: `sale_incl_gst: 'G1'`, `exp_incl_gst: 'G11'`, ... |
| `AUTO_NUMBER` | `'<Auto Number>'` — sentinel for auto-generated invoice numbers (the generated number appears as `InvoiceNumber` after the save refetch) |

## Raw-hash escape hatch

Because attributes pass through untouched, anything the API accepts works even
without a helper. The invoice write-only fields are the common case:

```ruby
Saasu::Invoice.create(
  'TransactionType' => 'S', 'Layout' => 'S', 'TransactionDate' => '2026-08-06',
  'LineItems'    => [{ 'Description' => 'Consulting', 'AccountId' => 123, 'TotalAmount' => 100.0 }],
  'QuickPayment' => { 'DatePaid' => '2026-08-06', 'BankedToAccountId' => 456, 'Amount' => 100.0 },
  'SendEmailToContact' => true,
  'EmailMessage' => { 'Subject' => 'Your invoice', 'Body' => 'Thanks!' }
)
```

Know that `QuickPayment` is accepted on POST only and that neither
`QuickPayment` nor `EmailMessage` is ever returned on GET — they are write
instructions, not state. Prefer the keyword helpers, which validate the field
names and constraints before any HTTP.
