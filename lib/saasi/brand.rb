module Saasi
  class Brand < Saasi::Base
    wraps Saasu::Brand

    attribute :id,   :integer
    attribute :name, :string
  end
end
