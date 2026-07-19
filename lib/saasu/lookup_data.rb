module Saasu
  class LookupData
    def self.countries
      Saasu::Client.request(:get, 'LookupData/Countries')
    end

    def self.currencies
      Saasu::Client.request(:get, 'LookupData/Currencies')
    end

    def self.date_formats
      Saasu::Client.request(:get, 'LookupData/DateFormats')
    end

    def self.industry_types
      Saasu::Client.request(:get, 'LookupData/IndustryTypes')
    end

    def self.number_formats
      Saasu::Client.request(:get, 'LookupData/NumberFormats')
    end

    def self.zones
      Saasu::Client.request(:get, 'LookupData/Zones')
    end
  end
end
