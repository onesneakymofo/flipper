require 'socket'
require 'thread'
require 'flipper/adapters/http'
require 'flipper/instrumenters/noop'
require 'flipper/adapters/memory'
require 'flipper/adapters/sync'
require 'flipper/cloud/producer'

module Flipper
  module Cloud
    class Configuration
      # The default url should be the one, the only, the website.
      DEFAULT_URL = "https://www.featureflipper.com/adapter".freeze

      # Public: The token corresponding to an environment on featureflipper.com.
      attr_accessor :token

      # Public: The url for http adapter (default: Flipper::Cloud::DEFAULT_URL).
      #         Really should only be customized for development work. Feel free
      #         to forget you ever saw this.
      attr_accessor :url

      # Public: net/http read timeout for all http requests (default: 5).
      attr_accessor :read_timeout

      # Public: net/http open timeout for all http requests (default: 5).
      attr_accessor :open_timeout

      # Public: IO stream to send debug output too. Off by default.
      #
      #  # for example, this would send all http request information to STDOUT
      #  configuration = Flipper::Cloud::Configuration.new
      #  configuration.debug_output = STDOUT
      attr_accessor :debug_output

      # Public: Instrumenter to use for the Flipper instance returned by
      #         Flipper::Cloud.new (default: Flipper::Instrumenters::Noop).
      #
      #  # for example, to use active support notifications you could do:
      #  configuration = Flipper::Cloud::Configuration.new
      #  configuration.instrumenter = ActiveSupport::Notifications
      attr_accessor :instrumenter

      # Internal: The producer used to buffer events as they happen and
      # eventually ship them to cloud. If provided, producer_options are
      # disregarded as it is assumed that you configured your producer's options
      # with exactly what you want.
      attr_accessor :producer

      # Public: The options passed to the default producer instance if no
      # producer is provided. See Producer#initialize for more. If producer is
      # provided, these options are disregarded.
      attr_accessor :producer_options

      # Public: Local adapter that all reads should go to in order to ensure
      # latency is low and resiliency is high. This adapter is automatically
      # kept in sync with cloud.
      #
      #  # for example, to use active record you could do:
      #  configuration = Flipper::Cloud::Configuration.new
      #  configuration.local_adapter = Flipper::Adapters::ActiveRecord.new
      attr_accessor :local_adapter

      # Public: Number of milliseconds between attempts to bring the local in
      # sync with cloud (default: 10_000 aka 10 seconds).
      attr_accessor :sync_interval

      def initialize(options = {})
        # Http adapter options.
        @token = options.fetch(:token)
        @url = options.fetch(:url, DEFAULT_URL)
        @read_timeout = options.fetch(:read_timeout, 5)
        @open_timeout = options.fetch(:open_timeout, 5)
        @instrumenter = options.fetch(:instrumenter, Instrumenters::Noop)
        @debug_output = options[:debug_output]

        # Sync adapter and wrapping.
        @sync_interval = options.fetch(:sync_interval, 10_000)
        @local_adapter = options.fetch(:local_adapter) { Adapters::Memory.new }
        @adapter_block = ->(adapter) { adapter }

        # Producer and options.
        @producer = options.fetch(:producer) do
          default_producer_options = {
            instrumenter: @instrumenter,
          }
          provided_producer_options = options.fetch(:producer_options) { {} }
          producer_options = default_producer_options.merge(provided_producer_options)
          Producer.new(self, producer_options)
        end

      end

      # Public: Read or customize the http adapter. Calling without a block will
      # perform a read. Calling with a block yields the cloud adapter
      # for customization.
      #
      #   # for example, to instrument the http calls, you can wrap the http
      #   # adapter with the intsrumented adapter
      #   configuration = Flipper::Cloud::Configuration.new
      #   configuration.adapter do |adapter|
      #     Flipper::Adapters::Instrumented.new(adapter)
      #   end
      #
      def adapter(&block)
        if block_given?
          @adapter_block = block
        else
          @adapter_block.call sync_adapter
        end
      end

      HOSTNAME = begin
                   Socket.gethostbyname(Socket.gethostname).first
                 rescue
                   Socket.gethostname
                 end

      def client
        client_options = {
          url: @url,
          read_timeout: @read_timeout,
          open_timeout: @open_timeout,
          debug_output: @debug_output,
          headers: {
            "FEATURE_FLIPPER_TOKEN" => @token,
            "FLIPPER_VERSION" => Flipper::VERSION,
            "FLIPPER_PLATFORM" => "ruby",
            "FLIPPER_PLATFORM_VERSION" => RUBY_VERSION,
            "FLIPPER_HOSTNAME" => HOSTNAME,
            "FLIPPER_PID" => Process.pid.to_s,
            "FLIPPER_THREAD" => Thread.current.object_id.to_s,
          },
        }
        Flipper::Adapters::Http::Client.new(client_options)
      end

      private

      def sync_adapter
        sync_options = {
          instrumenter: instrumenter,
          interval: sync_interval,
        }
        Flipper::Adapters::Sync.new(local_adapter, http_adapter, sync_options)
      end

      def http_adapter
        Flipper::Adapters::Http.new(client: client)
      end
    end
  end
end
