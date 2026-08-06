module Saasi
  class FileIdentity < Saasi::Base
    class FileSettings < Saasi::Base
      attribute :sale_amounts_include_tax,     :boolean
      attribute :purchase_amounts_include_tax, :boolean
    end

    wraps Saasu::FileIdentity

    attribute :id,                                     :integer
    attribute :name,                                   :string
    attribute :full_legal_name,                        :string
    attribute :trading_name_or_alternative_brand_name, :string
    attribute :business_identifier,                    :string
    attribute :company_identifier,                     :string
    attribute :primary_phone,                          :string
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
    attribute :subscription_name,                      :string

    has_one :file_settings, FileSettings

    # Legacy find is FileIdentity?FileId=<id> returning a raw hash — wrap it here
    def self.find(file_id)
      from_wire(Saasu::FileIdentity.find(file_id))
    end

    # Legacy update is a bare PUT FileIdentity (no id in path); generic #save can't express it
    def self.update(params)
      Saasu::FileIdentity.update(params)
    end
  end
end
