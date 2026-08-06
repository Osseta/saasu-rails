module Saasi
  class Company < Saasi::Base
    wraps Saasu::Company

    attribute :id,                        :integer
    attribute :name,                      :string
    attribute :abn,                       :string
    attribute :website,                   :string
    attribute :last_updated_id,           :string
    attribute :long_description,          :string
    attribute :logo_url,                  :string  # deprecated upstream; kept for reads
    attribute :trading_name,              :string
    attribute :company_email,             :string
    attribute :last_modified_date_utc,    :datetime
    attribute :created_date_utc,          :datetime
    attribute :last_modified_by_user_id,  :integer

    read_only :logo_url, :last_modified_date_utc, :created_date_utc, :last_modified_by_user_id
  end
end
