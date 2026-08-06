module Saasi
  class Item < Saasi::Base
    class BuildItem < Saasi::Base
      attribute :id,          :integer
      attribute :code,        :string
      attribute :description, :string
      attribute :quantity,    :decimal
    end

    wraps Saasu::Item

    attribute :id,                          :integer
    attribute :code,                        :string
    attribute :description,                 :string
    attribute :type,                        :string
    attribute :is_active,                   :boolean
    attribute :is_inventoried,              :boolean
    attribute :asset_account_id,            :integer
    attribute :is_sold,                     :boolean
    attribute :sale_income_account_id,      :integer
    attribute :sale_tax_code_id,            :integer
    attribute :sale_cos_account_id,         :integer, wire_key: 'SaleCoSAccountId'
    attribute :is_bought,                   :boolean
    attribute :purchase_expense_account_id, :integer
    attribute :purchase_tax_code_id,        :integer
    attribute :minimum_stock_level,         :decimal
    attribute :stock_on_hand,               :decimal
    attribute :current_value,               :decimal
    attribute :primary_supplier_contact_id, :integer
    attribute :primary_supplier_item_code,  :string
    attribute :default_re_order_quantity,   :decimal
    attribute :last_updated_id,             :string
    attribute :is_visible,                  :boolean
    attribute :is_virtual,                  :boolean
    attribute :vtype,                       :string, wire_key: 'VType'
    attribute :selling_price,               :decimal
    attribute :is_selling_price_inc_tax,    :boolean
    attribute :created_date_utc,            :datetime
    attribute :last_modified_date_utc,      :datetime
    attribute :last_modified_by,            :integer
    attribute :buying_price,                :decimal
    attribute :is_buying_price_inc_tax,     :boolean
    attribute :is_voucher,                  :boolean
    attribute :valid_from,                  :date
    attribute :valid_to,                    :date
    attribute :on_order,                    :decimal
    attribute :committed,                   :decimal
    attribute :notes,                       :string

    has_many :build_items, BuildItem

    read_only :stock_on_hand, :current_value, :created_date_utc,
              :last_modified_date_utc, :last_modified_by, :on_order, :committed

    validates :type, inclusion: { in: Saasu::Constants::ITEM_TYPES.values }, allow_nil: true

    # POST Item/:id/build — quantity of this combo item to assemble
    def build(quantity:)
      self.class.wraps.new('Id' => id).build('Quantity' => quantity)
    end
  end
end
