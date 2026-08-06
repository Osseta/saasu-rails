module Saasi
  class Search
    def initialize(keywords, params = {})
      @legacy = Saasu::Search.new(keywords, params)
    end

    def perform  = @legacy.perform
    def scope    = @legacy.scope
    def keywords = @legacy.keywords

    def contacts
      @legacy.contacts.map { |c| Saasi::Contact.from_wire(c.attributes) }
    end

    def invoices
      @legacy.invoices.map { |i| Saasi::Invoice.from_wire(i.attributes) }
    end

    def items
      @legacy.items.map { |i| Saasi::Item.from_wire(i.attributes) }
    end
  end
end
