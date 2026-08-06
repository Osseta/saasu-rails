module Saasi
  class ContactAggregate < Saasi::Base
    class Company < Saasi::Base
      attribute :id,               :integer
      attribute :name,             :string
      attribute :abn,              :string
      attribute :last_updated_id,  :string
      attribute :long_description, :string
      attribute :trading_name,     :string
      attribute :company_email,    :string
    end

    class ContactManager < Saasi::Base
      attribute :id,              :integer
      attribute :last_updated_id, :string
      attribute :salutation,      :string
      attribute :given_name,      :string
      attribute :middle_initials, :string
      attribute :family_name,     :string
      attribute :position_title,  :string
    end

    class Address < Saasi::Base
      attribute :street,   :string
      attribute :city,     :string
      attribute :state,    :string
      attribute :postcode, :string, wire_key: 'Postcode'
      attribute :country,  :string
    end

    wraps Saasu::ContactAggregate

    attribute :id,              :integer
    attribute :last_updated_id, :string
    attribute :salutation,      :string
    attribute :given_name,      :string
    attribute :middle_initials, :string
    attribute :family_name,     :string
    attribute :position_title,  :string
    attribute :primary_phone,   :string
    attribute :mobile_phone,    :string
    attribute :home_phone,      :string
    attribute :fax,             :string
    attribute :email_address,   :string
    attribute :contact_id,      :string  # free-text reference; a string in the API
    attribute :is_partner,      :boolean
    attribute :is_customer,     :boolean
    attribute :is_supplier,     :boolean
    attribute :is_contractor,   :boolean

    has_one :company,         Company
    has_one :contact_manager, ContactManager
    has_one :postal_address,  Address

    validates :salutation, inclusion: { in: ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.'] }, allow_nil: true
  end
end
