require 'open3'

module SNMP
  class Open
    # Open3-based data source that executes an snmp* command and captures the
    # output
    class CommandReader
      # see snmpcmd(1) for explanation of options
      OPTIONS = {
        version: '-v',
        auth_password: '-A',
        auth_protocol: '-a',
        community: '-c',
        context: '-n',
        no_check_increasing: {
          'snmpbulkwalk' => '-Cc',
          'snmpwalk' => '-Cc'
        },
        numeric: '-On', # needed by parser, should always be enabled
        priv_password: '-X', # not recommended, see snmp.conf(5)
        priv_protocol: '-x',
        sec_level: '-l',
        sec_user: '-u',
        retries: '-r',
        timeout: '-t',
        host: nil
      }.freeze

      OPTION_VALUES = {
        no_check_increasing: {
          true => ''
        }.freeze
      }.freeze

      # +options+ accepts options dealing with making connections to the host,
      # including all of the options listed in the +OPTIONS+ constant hash.
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
        opts = merge_options(options).merge('-On' => nil, host => nil)
        @command_options, @host_options = partition_options(opts)
      end

      def capture(cmd, oid, options = {})
        out, err = if @env
                     Open3.capture3(@env, cli(cmd, oid, options))
                   else
                     Open3.capture3(cli(cmd, oid, options))
                   end
        raise CommandTimeoutError, err.chomp if err =~ /^timeout/i
        raise CommandError, err.chomp unless err.empty?
        out
      end

      # Generate a CLI command string
      def cli(command, id = nil, options = {})
        command = normalize_command(command)

        [
          command,
          *options.map { |k, v| "#{k}#{v}" },
          *@host_options.map { |k, v| "#{k}#{v}" },
          *@command_options.fetch(command, {}).map { |k, v| "#{k}#{v}" },
          *id
        ].join(' ')
      end

      private

      def merge_options(options = {})
        options.each_pair.with_object({}) do |(key, value), opts|
          if OPTIONS.key?(key)
            opts[OPTIONS[key]] =
              (OPTION_VALUES.fetch(key, {}).fetch(value, value) || next)
          elsif key.is_a?(String)
            opts[key] = value
          else
            raise "Unknown option #{key}"
          end
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
  end # class Open
end # module SNMP
