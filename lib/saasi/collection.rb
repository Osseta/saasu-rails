module Saasi
  class Collection < Array
    attr_reader :metadata

    def initialize(records, metadata = {})
      super(records)
      @metadata = metadata
    end
  end
end
