module Fluent
  class HipchatSimpleOutput < BufferedOutput
    COLORS = %w(yellow red green purple gray random)
    LINE_BREAKS = { 'html' => "<br />", 'text' => "\n" }
    FORMAT = LINE_BREAKS.keys
    Fluent::Plugin.register_output('hipchat_simple', self)

    config_param :api_token, :string
    config_param :room, :string
    config_param :color, :string, :default => 'yellow'
    config_param :from, :string, :default => 'fluentd'
    config_param :notify, :bool, :default => false
    config_param :message_type, :string, :default => 'html'
    config_param :format, :string, :default => '${message}'
    config_param :display_record, :bool, :default => false
    config_param :http_proxy_host, :string, :default => nil
    config_param :http_proxy_port, :integer, :default => nil
    config_param :http_proxy_user, :string, :default => nil
    config_param :http_proxy_pass, :string, :default => nil
    config_param :flush_interval, :time, :default => 1
    config_param :add_hostname, :bool, :default => true

    attr_reader :hipchat

    def initialize
      super
      require 'hipchat-api'
      require 'erb'
    end

    def configure(conf)
      super

      @hipchat = HipChat::API.new(conf['api_token'])
      if conf['http_proxy_host']
        HipChat::API.http_proxy(
          conf['http_proxy_host'],
          conf['http_proxy_port'],
          conf['http_proxy_user'],
          conf['http_proxy_pass'])
      end
      @hostname = Socket.gethostname
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |(tag,time,record)|
        begin
          send_message(record)
        rescue => e
          $log.error("HipChat Error:", :error_class => e.class, :error => e.message)
        end
      end
    end

    private

    def send_message(record)
      message = format_message(record)
      response = @hipchat.rooms_message(@room, @from, message, @notify, @color, @message_type)
    end

    def format_message(record)
      result = ''
      record['hostname'] = @hostname if @add_hostname
      erb_template = @format.gsub(/\$\{([^}]+)\}/, '<%= record["\1"] %>')
      result = ERB.new(erb_template).result(binding)
      if @display_record
        result += LINE_BREAKS[message_type] * 2
        result += JSON.pretty_generate(record).gsub("\n", LINE_BREAKS[message_type])
      end
      result[0..5000]
    end
  end
end

