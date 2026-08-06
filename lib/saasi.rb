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
require 'saasi/brand'
require 'saasi/file_identity'
require 'saasi/invoice_attachment'
require 'saasi/user'
require 'saasi/search'
require 'saasi/payroll'

module Saasi
  def self.configure(&block)
    Saasu::Config.configure(&block)
  end

  LookupData = Saasu::LookupData
  Reports    = Saasu::Reports
end
