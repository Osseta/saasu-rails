# Saasu Model Relationships

Persisted Saasu resources exposed by this gem and how they relate. Fields are omitted — names and relationships only.

```mermaid
erDiagram
    Company ||--o{ Contact : "has contacts"
    Contact ||--o| ContactAggregate : "aggregated as"

    Contact ||--o{ Invoice : "billed / shipped to"
    Contact ||--o{ Journal : "journal contact"
    Contact ||--o{ Activity : "attached to"

    Brand ||--o{ Invoice : "templates (pdf/email)"
    Invoice ||--o{ InvoiceAttachment : "has attachments"
    Invoice }o--o{ Payment : "paid by"

    Account ||--o{ Payment : "payment account"
    Account ||--o{ Invoice : "line items post to"
    Account ||--o{ Journal : "journal lines post to"
    Account |o--o{ Account : "header / sub-accounts"

    TaxCode ||--o{ Invoice : "line item tax"
    TaxCode ||--o{ Journal : "journal line tax"
    TaxCode ||--o{ Item : "default sale/purchase tax"

    Item ||--o{ Invoice : "line items"
    Item ||--o{ ItemAdjustment : "adjusted by"
    Item ||--o{ ItemTransfer : "transferred by"

    Employee ||--o{ Timesheet : "submits"
    Employee ||--o{ LeaveRequest : "requests"
    Employee ||--o{ PayrollEntry : "paid via"
    Employee ||--o{ Payslip : "issued"
    Employee ||--o{ Entitlement : "accrues"
    Contact ||--o| Employee : "employee record"

    FileIdentity ||--o{ User : "has users"
    FileIdentity ||--o{ DeletedEntity : "tracks deletions"
```

Notes:

- Every resource is scoped to a Saasu file (`FileId`); only User and DeletedEntity are drawn against FileIdentity to avoid a hub-and-spoke diagram.
- `Employee`, `Timesheet`, `LeaveRequest`, `PayrollEntry`, `Payslip`, and `Entitlement` are the `Saasu::Payroll::*` classes.
- Search, LookupData, and Reports are excluded — they query or compute over the models above but store no data.
