require 'active_model'

require 'saasi/errors'
require 'saasi/collection'
require 'saasi/base'
require 'saasi/invoice'
require 'saasi/contact'
require 'saasi/payment'

module Saasi
  def self.configure(&block)
    Saasu::Config.configure(&block)
  end
end
