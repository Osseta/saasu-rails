require 'active_model'

require 'saasi/errors'
require 'saasi/collection'
require 'saasi/base'
require 'saasi/invoice'
require 'saasi/contact'
require 'saasi/payment'
require 'saasi/item'
require 'saasi/account'
require 'saasi/company'
require 'saasi/journal'
require 'saasi/tax_code'
require 'saasi/activity'
require 'saasi/item_adjustment'
require 'saasi/item_transfer'
require 'saasi/contact_aggregate'
require 'saasi/deleted_entity'

module Saasi
  def self.configure(&block)
    Saasu::Config.configure(&block)
  end
end
