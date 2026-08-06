require 'active_model'

require 'saasi/errors'
require 'saasi/collection'

module Saasi
  def self.configure(&block)
    Saasu::Config.configure(&block)
  end
end
