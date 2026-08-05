class Saasu::User < Saasu::Base
  def self.reset_password(username)
    raise "Username is required." if username.blank?
    # anonymous endpoint: must work for users who cannot authenticate
    Saasu::Client.request(:post, 'User/reset-password', { Username: username }, authenticate: false)['StatusMessage']
  end

  def self.current
    Saasu::Client.request(:get, 'User')
  end

  def self.update(params)
    Saasu::Client.request(:put, 'User', params)
  end

  def self.opt_in_to_2fa(params = {})
    Saasu::Client.request(:post, 'User/opt-in-to-2fa', params)
  end

  def self.opt_out_from_2fa(params = {})
    Saasu::Client.request(:post, 'User/opt-out-from-2fa', params)
  end

  def self.verify_2fa_opt_in(params = {})
    Saasu::Client.request(:post, 'User/verify-2fa-opt-in', params)
  end
end
