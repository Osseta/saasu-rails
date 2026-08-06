module Saasi
  class ItemTransfer < Saasi::Base
    class TransferItem < Saasi::Base
      attribute :quantity,          :decimal  # max 3 decimals per API docs
      attribute :inventory_item_id, :integer
      attribute :unit_cost,         :decimal
      attribute :line_total,        :decimal

      validates :quantity, :inventory_item_id, :unit_cost, presence: true
    end

    wraps Saasu::ItemTransfer

    attribute :id,                     :integer
    attribute :transaction_id,         :integer
    attribute :last_updated_id,        :string
    attribute :date,                   :date
    attribute :summary,                :string
    attribute :tags,                   :string_array
    attribute :requires_follow_up,     :boolean
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :notes,                  :string

    has_many :items, TransferItem

    read_only :created_date_utc, :last_modified_date_utc

    validates :date, presence: true
    validates :items, presence: true

    def id
      super || transaction_id
    end
  end
end
