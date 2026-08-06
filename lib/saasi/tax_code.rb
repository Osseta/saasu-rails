module Saasi
  class TaxCode < Saasi::Base
    wraps Saasu::TaxCode

    attribute :id,                        :integer
    attribute :code,                      :string
    attribute :name,                      :string
    attribute :rate,                      :decimal
    attribute :posting_account_id,        :integer
    attribute :is_sale,                   :boolean
    attribute :is_purchase,               :boolean
    attribute :is_payroll,                :boolean
    attribute :is_inbuilt,                :boolean
    attribute :is_shared,                 :boolean
    attribute :is_active,                 :boolean
    attribute :created_date_utc,          :datetime
    attribute :last_modified_date_utc,    :datetime
    attribute :last_modified_by_user_id,  :integer
    attribute :last_updated_id,           :string
    attribute :notes,                     :string
  end
end
