module Saasi
  class Invoice < Saasi::Base
    class LineItemAttribute < Saasi::Base
      attribute :attribute_id, :integer
      attribute :name,         :string
      attribute :value,        :string
    end

    class LineItem < Saasi::Base
      attribute :id,                  :integer
      attribute :description,         :string
      attribute :account_id,          :integer
      attribute :tax_code,            :string
      attribute :total_amount,        :decimal
      attribute :quantity,            :decimal
      attribute :unit_price,          :decimal
      attribute :percentage_discount, :decimal
      attribute :inventory_id,        :integer
      attribute :item_code,           :string
      attribute :tags,                :string_array
      has_many  :item_attributes, LineItemAttribute, wire_key: 'Attributes'
    end

    class QuickPayment < Saasi::Base
      attribute :date_paid,            :date
      attribute :date_cleared,         :date
      attribute :banked_to_account_id, :integer
      attribute :amount,               :decimal
      attribute :reference,            :string
      attribute :summary,              :string

      validates :date_paid, :banked_to_account_id, :amount, presence: true
      validate  :amount_has_at_most_two_decimals

      def amount_has_at_most_two_decimals
        errors.add(:amount, 'must have at most 2 decimal places') if amount && amount != amount.round(2)
      end
    end

    class EmailMessage < Saasi::Base
      attribute :from,    :string
      attribute :to,      :string
      attribute :subject, :string
      attribute :body,    :string
      attribute :cc,      :string
      attribute :bcc,     :string
    end

    class Terms < Saasi::Base
      attribute :type,               :integer
      attribute :interval,           :integer
      attribute :interval_type,      :integer
      attribute :type_enum,          :string
      attribute :interval_type_enum, :string
    end

    class AttachmentInfo < Saasi::Base
      attribute :id,                  :integer
      attribute :name,                :string
      attribute :description,         :string
      attribute :item_id_attached_to, :integer
      attribute :size,                :integer
    end

    wraps Saasu::Invoice

    attribute :id,                                 :integer
    attribute :transaction_id,                     :integer
    attribute :last_updated_id,                    :string
    attribute :currency,                           :string
    attribute :invoice_number,                     :string
    attribute :invoice_type,                       :string
    attribute :transaction_type,                   :string
    attribute :layout,                             :string
    attribute :brand_id,                           :integer # 0/null = default brand (new theme PDF/email)
    attribute :for_entity_type_id,                 :integer # Constants::FOR_ENTITY_TYPES
    attribute :summary,                            :string
    attribute :total_amount,                       :decimal
    attribute :total_tax_amount,                   :decimal
    attribute :is_tax_inc,                         :boolean
    attribute :amount_paid,                        :decimal
    attribute :amount_owed,                        :decimal
    attribute :fx_rate,                            :decimal
    attribute :auto_populate_fx_rate,              :boolean
    attribute :requires_follow_up,                 :boolean
    attribute :sent_to_contact,                    :boolean
    attribute :transaction_date,                   :date
    attribute :billing_contact_id,                 :integer
    attribute :billing_contact_first_name,         :string
    attribute :billing_contact_last_name,          :string
    attribute :billing_contact_organisation_name,  :string
    attribute :shipping_contact_id,                :integer
    attribute :shipping_contact_first_name,        :string
    attribute :shipping_contact_last_name,         :string
    attribute :shipping_contact_organisation_name, :string
    attribute :created_date_utc,                   :datetime
    attribute :last_modified_date_utc,             :datetime
    attribute :payment_status,                     :string
    attribute :due_date,                           :date
    attribute :invoice_status,                     :string
    attribute :purchase_order_number,              :string
    attribute :payment_count,                      :integer
    attribute :tags,                               :string_array
    attribute :notes_internal,                     :string
    attribute :notes_external,                     :string
    attribute :template_id,                        :integer
    attribute :send_email_to_contact,              :boolean

    has_many :line_items,    LineItem
    has_one  :terms,         Terms
    has_many :attachments,   AttachmentInfo
    has_one  :email_message, EmailMessage
    has_one  :quick_payment, QuickPayment

    read_only :billing_contact_first_name, :billing_contact_last_name,
              :billing_contact_organisation_name, :shipping_contact_first_name,
              :shipping_contact_last_name, :shipping_contact_organisation_name,
              :created_date_utc, :last_modified_date_utc, :payment_status,
              :invoice_status, :payment_count, :attachments

    validates :invoice_type, :transaction_type, :layout, :transaction_date, presence: true
    validates :line_items, presence: true
    validates :transaction_type, inclusion: { in: Saasu::Constants::INVOICE_TRANSACTION_TYPES.values }, allow_nil: true
    validates :layout, inclusion: { in: Saasu::Constants::INVOICE_LAYOUTS.values }, allow_nil: true
    validates :invoice_type, inclusion: { in: Saasu::Constants::INVOICE_TYPES }, allow_nil: true

    def id
      super || transaction_id
    end

    # QuickPayment is accepted by the API on POST only (never PUT, never returned on GET)
    def save
      raise "QuickPayment can only be set when creating an invoice (the API accepts it on POST only)" if persisted? && quick_payment
      super
    end

    # Non-CRUD helpers, delegated so migrated apps keep full method parity
    def self.sales_stats_summary(params = {})
      Saasu::Invoice.sales_stats_summary(params)
    end

    def email(email_address = nil)
      self.class.wraps.new('Id' => id).email(email_address)
    end

    def generate_pdf(template_id = nil, print_as: nil)
      self.class.wraps.new('Id' => id).generate_pdf(template_id, print_as: print_as)
    end
  end
end
