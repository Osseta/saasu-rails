require 'spec_helper'

describe Saasu::Activity do
  describe "filters" do
    it 'accepts AttachedToType and AttachedToId' do
      expect { Saasu::Activity.validate_filters(AttachedToType: 'Sale', AttachedToId: 1) }.
        not_to raise_error
    end
  end
end
