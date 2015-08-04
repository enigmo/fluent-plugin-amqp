module Fluent
  class AMQPOutput < BufferedOutput
    Plugin.register_output("amqp", self)

    config_param :host, :string, :default => nil
    config_param :user, :string, :default => "guest"
    config_param :pass, :string, :default => "guest"
    config_param :vhost, :string, :default => "/"
    config_param :port, :integer, :default => 5672
    config_param :ssl, :bool, :default => false
    config_param :verify_ssl, :bool, :default => false
    config_param :exchange, :string, :default => ""
    config_param :exchange_type, :string, :default => "direct"
    config_param :passive, :bool, :default => false
    config_param :durable, :bool, :default => false
    config_param :auto_delete, :bool, :default => false
    config_param :key, :string, :default => nil
    config_param :persistent, :bool, :default => false
    config_param :x_dead_letter_exchange, :string, :default => nil

    def initialize
      super
      require "bunny"
    end

    def configure(conf)
      super
      @conf = conf
      unless @host && @exchange && @key
        raise ConfigError, "'host', 'exchange' and 'key' must be all specified."
      end
      @bunny = Bunny.new(:host => @host, :port => @port, :vhost => @vhost,
                         :pass => @pass, :user => @user, :ssl => @ssl, :verify_ssl => @verify_ssl)
    end

    def start
      super
      @bunny.start
      channel = @bunny.create_channel
      @queue  = channel.queue(@key, queue_options)
    end

    def shutdown
      super
      @bunny.stop
    end

    def format(tag, time, record)
      record.to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |data|
        @queue.publish(data.to_json, :type => @exchange_type, :key => @key, :persistent => @persistent)
      end
    end

    private

      def queue_options
        opts = { :auto_delete => @auto_delete,:durable => @durable, :passive => @passive }
        if @x_dead_letter_exchange
          opts.merge!({
            :arguments => { :'x-dead-letter-exchange' => @x_dead_letter_exchange }
          })
        end
        opts
      end

  end
end
