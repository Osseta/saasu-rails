require 'spec_helper'

describe Saasu::Contact do
  describe "filters" do
    it 'accepts OrganisationName' do
      expect { Saasu::Contact.validate_filters(OrganisationName: 'Acme') }.
        not_to raise_error
    end
  end
end
