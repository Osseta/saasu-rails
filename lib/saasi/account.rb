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
