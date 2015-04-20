require 'helper'
class HipchatSimpleOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  DEFAULT_CONFIG = %[

  ]

  def create_driver(conf = DEFAULT_CONFIG)
    config = %[
      apikey testkey
      buffer_path tmp/buffer
    ] + conf

    Fluent::Test::BufferedOutputTestDriver.new(Fluent::HipchatSimpleOutput) do
      def write(chunk)
        chunk.instance_variable_set(:@key, @key)
        super(chunk)
      end
    end.configure(config)
  end


  def test_configure
    d = create_driver

    {:@apikey => 'testkey', :@use_ssl => true, :@auto_create_table => true,
     :@buffer_type => 'file', :@flush_interval => 300}.each { |k, v|
      assert_equal(d.instance.instance_variable_get(k), v)
    }
  end

  def test_emit
    d = create_driver
    time, records = stub_seed_values
    database, table = d.instance.instance_variable_get(:@key).split(".", 2)
    stub_td_table_create_request(database, table)
    stub_td_import_request(stub_request_body(records, time), database, table)

    records.each { |record|
      d.emit(record, time)
    }
    d.run

    assert_equal('TD1 testkey', @auth_header)
  end
end
