require 'spec_helper'
include ConcreteStoreHelper

describe MongoEntityStore do

  let(:store) do
    MongoEntityStore.connection_profile = "mongodb://localhost/entity_store_default"
    MongoEntityStore.new
  end

  store_test_suite

end
