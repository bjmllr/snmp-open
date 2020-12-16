require 'open3'
require 'snmp/open/options'

module SNMP
  class Open
    # Open3-based data source that executes an snmp* command and captures the
    # output
    class CommandReader
      # +options+ accepts options dealing with making connections to the host,
      # including all of the options listed in the +Options::MAP+ constant hash.
      # Other options can be given as strings (or any object with a suitable
      # +to_s+ method), e.g., these are equivalent:
      #
      #   SNMP::Open.new(host: hostname, timeout: 3, '-m' => miblist)
      #   SNMP::Open.new(hostname => nil, '-t' => '3', '-m' => miblist)
      #
      def initialize(options)
        @env = options.delete(:env)
        host = options.delete(:host) ||
               (raise ArgumentError, 'Host expected but not given')
        opts = Options::REQUIRED_BY_PARSER
               .merge(merge_options(options))
               .merge(host => nil)
        @command_options, @host_options = partition_options(opts)
      end

      def capture(cmd, oid, options = {})
        out, err = if @env
                     Open3.capture3(@env, cli(cmd, oid, options))
                   else
                     Open3.capture3(cli(cmd, oid, options))
                   end
        raise_capture_errors(err)
        out
      end

      # Generate a CLI command string
      def cli(command, id = nil, options = {})
        command = normalize_command(command)

        [
          command,
          *options.map { |k, v| "#{k}#{v}" },
          *oid_options(id),
          *@host_options.map { |k, v| "#{k}#{v}" },
          *@command_options.fetch(command, {}).map { |k, v| "#{k}#{v}" },
          *id
        ].join(' ')
      end

      private

      def raise_capture_errors(err)
        case err
        when /^Cannot find module \(([^)]+)\)/
          raise UnknownMIBError, "Unknown MIB: #{Regexp.last_match(1)}"
        when /^(\S+): Unknown Object Identifier$/
          raise UnknownOIDError, "Unknown OID: #{Regexp.last_match(1)}"
        when /^timeout/i
          raise CommandTimeoutError, err.chomp
        when /./
          raise CommandError, err.chomp
        end
      end

      def merge_options(options = {})
        options.each_pair.with_object({}) do |(key, value), opts|
          if Options::MAP.key?(key)
            opts[Options::MAP[key]] =
              (Options::VALUES.fetch(key, {}).fetch(value, value) || next)
          elsif key.is_a?(String)
            opts[key] = value
          else
            raise "Unknown option #{key}"
          end
        end
      end

      # if the request OID is all-numeric, force numeric OID in the output
      def oid_options(id)
        if id =~ /[^0-9.]/
          []
        else
          ['-On']
        end
      end

      def normalize_command(command)
        case command
        when Symbol then "snmp#{command}"
        else             command.to_s
        end
      end

      def partition_options(options)
        command_keys, host_keys = options
                                  .keys
                                  .partition { |k| k.is_a?(Hash) }

        [
          merge_command_options(options, command_keys),
          merge_host_options(options, host_keys)
        ]
      end

      def merge_command_options(options, keys)
        keys.each.with_object({}) do |commands, hash|
          command_value = options[commands]
          commands.each_pair do |command, option|
            hash[command] ||= {}
            hash[command][option] = command_value
          end
        end
      end

      def merge_host_options(options, keys)
        keys.each.with_object({}) do |key, hash|
          hash[key] = options[key]
        end
      end
    end # class CommandReader

    class CommandError < RuntimeError; end
    class CommandTimeoutError < CommandError; end
    class UnknownMIBError < CommandError; end
    class UnknownOIDError < CommandError; end
  end # class Open
end # module SNMP
