module Saasi
  class Activity < Saasi::Base
    class AttachmentInfo < Saasi::Base
      attribute :id,                  :integer
      attribute :name,                :string
      attribute :description,         :string
      attribute :item_id_attached_to, :integer
      attribute :size,                :integer
    end

    wraps Saasu::Activity

    attribute :id,                     :integer
    attribute :last_updated_id,        :string
    attribute :activity_type,          :string
    attribute :done,                   :boolean
    attribute :due,                    :date
    attribute :title,                  :string
    attribute :owner_first_name,       :string
    attribute :owner_last_name,        :string
    attribute :owner_email,            :string
    attribute :attached_to_type,       :string
    attribute :attached_to_id,         :integer
    attribute :tags,                   :string_array
    attribute :created_date_utc,       :datetime
    attribute :last_modified_date_utc, :datetime
    attribute :details,                :string

    has_many :attachments, AttachmentInfo

    # Owner names are derived from the user record looked up via OwnerEmail —
    # email is the assignment key (writable), the names are display fields.
    read_only :owner_first_name, :owner_last_name, :created_date_utc,
              :last_modified_date_utc, :attachments

    # case-insensitive: the docs list PascalCase values but API responses return lowercase
    validate :attached_to_type_is_known

    def attached_to_type_is_known
      return if attached_to_type.nil?
      return if Saasu::Constants::ATTACHED_TO_TYPES.any? { |t| t.casecmp?(attached_to_type) }

      errors.add(:attached_to_type, 'is not included in the list')
    end
  end
end
