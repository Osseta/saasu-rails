module Saasi
  class User
    class << self
      def reset_password(username) = Saasu::User.reset_password(username)
      def current                  = Saasu::User.current
      def update(params)           = Saasu::User.update(params)
      def opt_in_to_2fa(params = {})      = Saasu::User.opt_in_to_2fa(params)
      def opt_out_from_2fa(params = {})   = Saasu::User.opt_out_from_2fa(params)
      def verify_2fa_opt_in(params = {})  = Saasu::User.verify_2fa_opt_in(params)
    end
  end
end
