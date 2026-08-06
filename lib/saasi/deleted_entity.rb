module Saasi
  class DeletedEntity < Saasi::Base
    wraps Saasu::DeletedEntity

    attribute :id,              :integer # never populated (tombstones carry no own id); satisfies Base#persisted?
    attribute :entity_type,     :string
    attribute :entity_id,       :integer
    attribute :deleted_by_user, :string
    attribute :timestamp,       :datetime

    validates :entity_type, inclusion: { in: Saasu::Constants::DELETED_ENTITY_TYPES }, allow_nil: true
  end
end
