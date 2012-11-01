require 'test_helper'
require 'omf_ec/group_context'

describe OmfEc::GroupContext do
  before do
    @context = OmfEc::GroupContext.new(name: 'bob', type: 'engine', group: 'universe')
  end

  describe "when initialised with options" do
    it "must be able to respond to random group operation method" do
      @context.bob = 5

      @context.alice
    end
  end
end
