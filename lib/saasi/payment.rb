module Saasi
  class Payment < Saasi::Base
    class PaymentItem < Saasi::Base
      attribute :invoice_transaction_id, :integer
      attribute :amount_paid,            :decimal

      validates :invoice_transaction_id, :amount_paid, presence: true
    end

    wraps Saasu::Payment

    attribute :id,                     :integer
    attribute :transaction_id,         :integer
    attribute :transaction_date,       :date
    attribute :transaction_type,       :string
    attribute :payment_account_id,     :integer
    attribute :total_amount,           :decimal
    attribute :fee_amount,             :decimal
    attribute :summary,                :string
    attribute :reference,              :string
    attribute :cleared_date,           :date
    attribute :currency,               :string
    attribute :auto_populate_fx_rate,  :boolean
    attribute :fx_rate,                :decimal
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :last_updated_id,        :string
    attribute :requires_follow_up,     :boolean
    attribute :notes,                  :string

    has_many :payment_items, PaymentItem

    read_only :created_date_utc, :last_modified_date_utc

    validates :transaction_date, :transaction_type, :payment_account_id, presence: true
    validates :payment_items, presence: true
    validates :transaction_type, inclusion: { in: Saasu::Constants::PAYMENT_TRANSACTION_TYPES.values }, allow_nil: true

    def id
      super || transaction_id
    end
  end
end
