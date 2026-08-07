module Saasi
  class Contact < Saasi::Base
    class Address < Saasi::Base
      attribute :street,   :string
      attribute :city,     :string
      attribute :state,    :string
      attribute :postcode, :string, wire_key: 'Postcode'
      attribute :country,  :string
    end

    class TradingTerms < Saasi::Base
      attribute :trading_terms_type,          :integer
      attribute :trading_terms_interval,      :integer
      attribute :trading_terms_interval_type, :integer
    end

    class BpayDetails < Saasi::Base
      attribute :biller_code, :string
      attribute :crn,         :string, wire_key: 'CRN'
    end

    class ChequeDetails < Saasi::Base
      attribute :accept_cheque,     :boolean
      attribute :cheque_payable_to, :string
    end

    class DirectDepositDetails < Saasi::Base
      attribute :accept_direct_deposit, :boolean
      attribute :account_name,          :string
      attribute :account_bsb,           :string, wire_key: 'AccountBSB'
      attribute :account_number,        :string
    end

    wraps Saasu::Contact

    attribute :id,                        :integer
    attribute :created_date_utc,          :datetime
    attribute :last_modified_date_utc,    :datetime
    attribute :last_updated_id,           :string
    attribute :salutation,                :string
    attribute :given_name,                :string
    attribute :middle_initials,           :string
    attribute :family_name,               :string
    attribute :is_active,                 :boolean
    attribute :company_id,                :integer
    attribute :position_title,            :string
    attribute :website_url,               :string
    attribute :primary_phone,             :string
    attribute :home_phone,                :string
    attribute :other_phone,               :string
    attribute :mobile_phone,              :string
    attribute :fax,                       :string
    attribute :email_address,             :string
    attribute :contact_id,                :string  # free-text reference; a string in the API
    attribute :contact_manager_id,        :integer
    attribute :custom_field1,             :string, wire_key: 'CustomField1'
    attribute :custom_field2,             :string, wire_key: 'CustomField2'
    attribute :twitter_id,                :string
    attribute :skype_id,                  :string
    attribute :linked_in_profile,         :string
    attribute :auto_send_statement,       :boolean
    attribute :is_ocr_sender,             :boolean # default false server-side
    attribute :ocr_recipient_alias,       :string
    attribute :additional_emails,         :string  # comma-separated list in a single string
    attribute :is_partner,                :boolean
    attribute :is_customer,               :boolean
    attribute :is_supplier,               :boolean
    attribute :is_contractor,             :boolean
    attribute :tags,                      :string_array
    attribute :default_sale_discount,     :decimal
    attribute :default_purchase_discount, :decimal
    attribute :last_modified_by_user_id,  :integer

    has_one :direct_deposit_details, DirectDepositDetails
    has_one :cheque_details,         ChequeDetails
    has_one :bpay_details,           BpayDetails
    has_one :postal_address,         Address
    has_one :other_address,          Address
    has_one :sale_trading_terms,     TradingTerms
    has_one :purchase_trading_terms, TradingTerms

    read_only :created_date_utc, :last_modified_date_utc, :last_modified_by_user_id

    validates :salutation, inclusion: { in: ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.'] }, allow_nil: true

    # Non-CRUD helper parity with the legacy class (statement PDF)
    def generate_pdf(from_date:, to_date:, generate_type: 'Statement')
      self.class.wraps.new('Id' => id).generate_pdf(from_date: from_date, to_date: to_date, generate_type: generate_type)
    end
  end
end
