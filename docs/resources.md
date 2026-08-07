# Resource Reference

Every resource exists in both namespaces (`Saasu::X` hash-based,
`Saasi::X` typed) with the same operations and filters — the typed class
delegates to the legacy one. Operations key: **L**ist (`all`/`where`),
**F**ind, **C**reate, **U**pdate/save, **D**elete.

Filters are passed to `.where` exactly as listed (PascalCase). `Page` and
`PageSize` control paging wherever listed (`PageSize` default 25, max 100).
Date filters take `YYYY-MM-DD` strings; range ends must be supplied as pairs.
Filters marked † are accepted by the gem for compatibility but are not in the
current API documentation.

| Resource | Ops | Filters | Special methods |
|---|---|---|---|
| `Account` | LFCUD | IsActive, IsBankAccount, AccountType, IncludeBuiltIn, HeaderAccountId, AccountLevel, Page, PageSize | `.bank_account_balances(params)` |
| `Activity` | LFCUD | LastModifiedFromDate/ToDate, Tags, TagSelection, FromDate, ToDate, SearchText, ActivityStatus, ActivityType, OwnerEmail, AttachedToType†, AttachedToId†, Page, PageSize | — |
| `Brand` | L | — | — |
| `Company` | LFCUD | LastModifiedFromDate/ToDate, CompanyName, Page, PageSize | — |
| `Contact` | LFCUD | LastModifiedFromDate/ToDate, GivenName, FamilyName, CompanyName, CompanyId, OrganisationName†, IsActive, IsCustomer, IsSupplier, IsContractor, IsPartner, Tags, TagSelection, Email, ContactId, Page, PageSize | `#generate_pdf(from_date:, to_date:)` — statement PDF |
| `ContactAggregate` | FCU | — | contact + company + contact manager + postal address in one round-trip |
| `DeletedEntity` | L | EntityType, UtcDeletedFromDate, UtcDeletedToDate, Page, PageSize | tombstone feed for sync; defaults to the last 24 hours without explicit `UtcDeleted*` bounds |
| `FileIdentity` | LF | — | `.find(file_id)` (query-param form), `.update(params)` |
| `Invoice` | LFCUD | InvoiceNumber, PurchaseOrderNumber, LastModifiedFromDate/ToDate, TransactionType, Tags, TagSelection, InvoiceFromDate/ToDate, InvoiceStatus, PaymentStatus, BillingContactId, Page, PageSize | `#email`, `#email(address)`, `#generate_pdf(template_id, print_as:)` (`PRINT_AS` values), `.sales_stats_summary(params)`; legacy: `#add_quick_payment`, `#email_on_save`; Saasi: `quick_payment=`, `send_email_to_contact=`/`email_message=`, `brand_id`, `for_entity_type_id` |
| `InvoiceAttachment` | F C D | — | `.for_invoice(invoice_id)`, `.upload(invoice_id, file, name:, description:, overwrite:)`, `#decoded_data` |
| `Item` | LFCUD | LastModifiedFromDate/ToDate, IsActive, ItemType, SearchMethod, SearchText, Page, PageSize | `#build` (assemble combo item) |
| `ItemAdjustment` | LFCUD | LastModifiedFromDate/ToDate, Tags, TagSelection, FromDate, ToDate, Page, PageSize | — |
| `ItemTransfer` | LFCUD | LastModifiedFromDate/ToDate, Tags, TagSelection, FromDate, ToDate, Page, PageSize | — |
| `Journal` | LFCUD | LastModifiedFromDate/ToDate, Tags, TagSelection, FromDate, ToDate, JournalContactId, Page, PageSize | — |
| `Payment` | LFCUD | LastModifiedFromDate/ToDate, ForInvoiceId, ClearedFromDate/ToDate, TransactionType, PaymentFromDate/ToDate, PaymentAccountId, SortString†, Page, PageSize | allocates to invoices via `PaymentItems`; defaults to the last month without a `PaymentFromDate/ToDate` pair |
| `TaxCode` | LF | IsActive, Page, PageSize | read-only resource |
| `User` | — | — | `.reset_password(username)` (anonymous), `.current`, `.update(params)`, `.opt_in_to_2fa`, `.opt_out_from_2fa`, `.verify_2fa_opt_in` |
| `Search` | — | — | `new(keywords, scope:, transaction_type:, page:, page_size:, include_search_term_highlights:)` → `#perform`, `#contacts`, `#invoices`, `#items` |
| `Payroll::Employee` | LF | IsActive, IncludeLeaveBalances, LeaveBalanceAsAtDate, Page†, PageSize† | read-only; includes inactive employees by default; leave balances only with `IncludeLeaveBalances=true` |
| `Payroll::Entitlement` | L | Page†, PageSize† | `Items` envelope; pay-item ids used by leave requests |
| `Payroll::PayrollEntry` | L | FromDate, ToDate, EmployeeId, Page, PageSize | envelope totals (`TotalWages`, ...) land in `collection.metadata` |
| `Payroll::LeaveRequest` | FCUD | — | Saasi validates: status enum, end ≥ start, ≤ 63 days, items required when Approved; concurrency via `LastModifiedDateUtc` |
| `Payroll::Timesheet` | FCUD | — | Saasi validates contact/start/finish presence; concurrency via `LastUpdatedId` |
| `Payroll::Payslip` | — | — | `.generate_pdf(payroll_entry_id)` (`template_id` accepted for compatibility, undocumented) |
| `LookupData` | — | — | `.countries`, `.currencies`, `.date_formats`, `.industry_types`, `.number_formats`, `.zones` |
| `Reports` | — | — | `.profit_and_loss_summary(params)`, `.profit_and_loss_summary_by_account_type(params)` |

Notes:

- Ops reflect what the Saasu API supports per resource; calling an unsupported
  operation raises `"This method is not currently supported by Saasu API"`
  locally, before any HTTP.
- Legal values for coded filters (`InvoiceStatus`, `PaymentStatus`,
  `TransactionType`, `TagSelection`, `ItemType`, `SearchMethod`,
  `ActivityStatus`, `AttachedToType`, `EntityType`, ...) are collected in
  [`Saasu::Constants`](saasu-legacy.md#wire-vocabularies--saasuconstants).
- Invoice `TransactionType` is `S`/`P`; Payment `TransactionType` is
  `SP`/`PP`.
- The entity-relationship picture across resources is in
  [models.md](models.md).
