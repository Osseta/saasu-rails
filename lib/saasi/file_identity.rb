module Saasi
  class FileIdentity < Saasi::Base
    class TradingTerms < Saasi::Base
      attribute :trading_terms_type,          :integer
      attribute :trading_terms_interval,      :integer
      attribute :trading_terms_interval_type, :integer
    end

    class FileSettings < Saasi::Base
      attribute :sale_amounts_include_tax,     :boolean
      attribute :purchase_amounts_include_tax, :boolean
      has_one :sale_trading_terms,     TradingTerms
      has_one :purchase_trading_terms, TradingTerms
    end

    wraps Saasu::FileIdentity

    # Id and SubscriptionName belong to the FileIdentities list (summary) shape;
    # the remainder is the FileIdentity detail shape. One model covers both.
    attribute :id,                                     :integer
    attribute :name,                                   :string
    attribute :full_legal_name,                        :string
    attribute :trading_name_or_alternative_brand_name, :string
    attribute :business_identifier,                    :string
    attribute :business_identifier_branch_number,      :integer # ABN branch number in AU
    attribute :company_identifier,                     :string
    attribute :industry_type_id,                       :integer # ids from LookupData/IndustryTypes; required for PUT
    attribute :primary_phone,                          :string
    attribute :fax,                                    :string
    attribute :website,                                :string
    attribute :email,                                  :string
    attribute :street,                                 :string
    attribute :city,                                   :string
    attribute :state,                                  :string
    attribute :post_code,                              :string, wire_key: 'PostCode'
    attribute :country,                                :string
    attribute :zone,                                   :string
    attribute :currency_code,                          :string
    attribute :is_tax_registered,                      :boolean
    attribute :tax_registration_date,                  :date # must be set when is_tax_registered
    attribute :date_time_format_id,                    :integer # deprecated upstream
    attribute :number_format_id,                       :integer # deprecated upstream
    attribute :financial_year_end_month,               :integer
    attribute :financial_year_end_date,                :integer
    attribute :payroll_year_end_month,                 :integer # immutable for AU (STP)
    attribute :payroll_year_end_date,                  :integer # immutable for AU (STP)
    attribute :last_updated_id,                        :string  # concurrency token, required for PUT
    attribute :created_date_utc,                       :datetime
    attribute :last_modified_date_utc,                 :datetime
    attribute :last_modified_by_user_id,               :integer
    attribute :subscription_name,                      :string

    has_one :file_settings, FileSettings

    # zone/currency_code are set at file creation and cannot change;
    # file_settings is deprecated upstream and documented read-only
    read_only :zone, :currency_code, :file_settings,
              :created_date_utc, :last_modified_date_utc, :last_modified_by_user_id

    # Legacy find is FileIdentity?FileId=<id> returning a raw hash — wrap it here
    # (unlike Saasu::Base.find, the legacy FileIdentity.find has no .present?
    # guard, so a blank 200 body comes back as "" rather than nil — .presence
    # normalizes that before we hand it to from_wire)
    def self.find(file_id)
      (hash = Saasu::FileIdentity.find(file_id).presence) && from_wire(hash)
    end

    # Legacy update is a bare PUT FileIdentity (no id in path); generic #save can't express it
    def self.update(params)
      Saasu::FileIdentity.update(params)
    end
  end
end
