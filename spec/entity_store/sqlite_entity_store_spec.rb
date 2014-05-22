require 'spec_helper'
include ConcreteStoreHelper

describe SqliteEntityStore do

  let(:store) do
    SqliteEntityStore.connection_profile = "sqlite3://:memory:"
    SqliteEntityStore.new
  end

  store_test_suite

end
