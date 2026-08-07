module Saasi
  class Brand < Saasi::Base
    wraps Saasu::Brand

    attribute :id,                                   :integer
    attribute :name,                                 :string
    attribute :is_default,                           :boolean
    attribute :use_contact_details_in_file_identity, :boolean
    attribute :website_url,                          :string
    attribute :email_address,                        :string
    attribute :primary_phone,                        :string
    attribute :street,                               :string
    attribute :city,                                 :string
    attribute :post_code,                            :string, wire_key: 'PostCode'
    attribute :country_id,                           :integer
  end
end
