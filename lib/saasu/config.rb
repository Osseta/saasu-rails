module Saasu
  class Config
    class_attribute :username, :password, :file_id, :api_url, :two_factor_code, :scope

    class << self
      def configure
        yield self
      end
    end
  end
end
