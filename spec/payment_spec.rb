require 'spec_helper'

describe Saasu::Payment do
  describe "filters" do
    it 'accepts SortString' do
      expect { Saasu::Payment.validate_filters(SortString: 'TransactionDate') }.
        not_to raise_error
    end
  end
end
