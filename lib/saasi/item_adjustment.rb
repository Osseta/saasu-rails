module Saasi
  class ItemAdjustment < Saasi::Base
    class AdjustmentItem < Saasi::Base
      attribute :quantity,    :decimal  # max 3 decimals per API docs
      attribute :item_id,     :integer
      attribute :account_id,  :integer
      attribute :unit_price,  :decimal
      attribute :total_price, :decimal
    end

    wraps Saasu::ItemAdjustment

    attribute :id,                     :integer
    attribute :transaction_id,         :integer
    attribute :date,                   :date
    attribute :summary,                :string
    attribute :requires_follow_up,     :boolean
    attribute :last_updated_id,        :string
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :tags,                   :string_array
    attribute :notes,                  :string

    has_many :adjustment_items, AdjustmentItem

    read_only :created_date_utc, :last_modified_date_utc

    def id
      super || transaction_id
    end
  end
end
