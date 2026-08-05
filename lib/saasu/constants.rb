module Saasu
  # Wire vocabularies for filter/field values, ported from the official
  # .NET SDK (Saasu.API.Core Globals/ApiConstants and enums).
  module Constants
    INVOICE_STATUSES = { invoice: 'I', quote: 'Q', order: 'O' }.freeze
    PAYMENT_STATUSES = { paid: 'P', unpaid: 'U', all: 'A' }.freeze

    # TransactionType filter on Invoices vs Payments
    INVOICE_TRANSACTION_TYPES = { sale: 'S', purchase: 'P' }.freeze
    PAYMENT_TRANSACTION_TYPES = { sale_payment: 'SP', purchase_payment: 'PP' }.freeze

    TAG_SELECTIONS = %w(requireAll requireAny excludeAll excludeAny).freeze

    ACCOUNT_TYPES = ['Income', 'Expense', 'Asset', 'Equity', 'Liability',
                     'Other Income', 'Other Expense', 'Cost of Sales'].freeze

    ITEM_TYPES = { inventory: 'I', combo: 'C' }.freeze
    SEARCH_METHODS = %w(Contains StartsWith).freeze # SearchText max 128 chars, required with SearchMethod

    ACTIVITY_STATUSES = %w(todo done overdue).freeze
    ATTACHED_TO_TYPES = %w(Contact Employee Sale Purchase).freeze

    DELETED_ENTITY_TYPES = %w(Sale Purchase SalePayment PurchasePayment Item Contact Journal).freeze

    SEARCH_SCOPES = %w(All Transactions Contacts InventoryItems).freeze
    SEARCH_TRANSACTION_TYPES = %w(Transactions.Sale Transactions.Purchase Transactions.Journal Transactions.Payroll).freeze

    # OAuth token scopes; fileid takes a context suffix, e.g. "fileid:1234"
    OAUTH_SCOPES = %w(view modify delete full fileid).freeze

    INVOICE_LAYOUTS = { item: 'I', service: 'S', purchase: 'P' }.freeze

    INVOICE_TYPES = ['Tax Invoice', 'Sale Invoice', 'Purchase Invoice', 'Adjustment Note',
                     'Credit Note', 'Debit Note', 'Payment Invoice', 'RCT Invoice',
                     'Money In (Income)', 'Money Out (Expense)', 'Purchase Order', 'Sale Order',
                     'Quote', 'Pre-Quote Opportunity', 'Self-Billing', 'Consignment'].freeze

    # BAS tax codes
    TAX_CODES = {
      sale_incl_gst: 'G1',
      sale_gst_free: 'G1,G3',
      sale_input_taxed: 'G1,G4',
      sale_exports: 'G1,G2',
      sale_adjustments: 'G7',
      exp_incl_gst: 'G11',
      exp_gst_free: 'G11,G14',
      cap_ex_incl_gst: 'G10',
      cap_ex_gst_free: 'G10,G14',
      exp_adjustments: 'G18',
      salary_wage_other_paid: 'W1',
      withheld_tax_on_salary_wage: 'W1,W2',
      withheld_invest_distrib_no_tfn: 'W3',
      withheld_payment_no_abn: 'W4',
      wine_equalisation_tax_payable: '1C',
      wine_equalisation_tax_refundable: '1D',
      luxury_car_tax_payable: '1E',
      luxury_car_tax_refundable: '1F',
    }.freeze

    # Sentinel for auto-generated invoice numbers
    AUTO_NUMBER = '<auto number>'.freeze
  end
end
