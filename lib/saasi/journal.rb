module Saasi
  class Journal < Saasi::Base
    class JournalItem < Saasi::Base
      attribute :type,       :string
      attribute :account_id, :integer
      attribute :tax_code,   :string
      attribute :amount,     :decimal

      validates :type, inclusion: { in: %w(Credit Debit) }, allow_nil: true
    end

    wraps Saasu::Journal

    attribute :id,                            :integer
    attribute :transaction_id,                :integer
    attribute :last_updated_id,               :string
    attribute :transaction_date,              :date
    attribute :summary,                       :string
    attribute :currency,                      :string
    attribute :fx_rate,                       :decimal
    attribute :auto_populate_fx_rate,         :boolean
    attribute :reference,                     :string
    attribute :journal_contact_id,            :integer
    attribute :contact_first_name,            :string
    attribute :contact_last_name,             :string
    attribute :contact_organisation_name,     :string
    attribute :requires_follow_up,            :boolean
    attribute :tags,                          :string_array
    attribute :created_date_utc,              :datetime
    attribute :last_modified_date_utc,        :datetime
    attribute :notes,                         :string

    has_many :items, JournalItem

    read_only :contact_first_name, :contact_last_name, :contact_organisation_name,
              :created_date_utc, :last_modified_date_utc

    validates :transaction_date, presence: true
    validates :items, presence: true

    def id
      super || transaction_id
    end
  end
end
