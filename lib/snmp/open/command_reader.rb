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
        numeric: '-On', # needed by parser, should always be enabled
        priv_password: '-X', # not recommended, see snmp.conf(5)
        priv_protocol: '-x',
        sec_level: '-l',
        sec_user: '-u',
        retries: '-r',
        timeout: '-t',
        host: nil
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
        host = options.delete(:host) ||
               (raise ArgumentError, 'Host expected but not given')
        @host_options = merge_options(options).merge('-On' => nil, host => nil)
      end

      def capture(cmd, oid, options = {})
        out, err = Open3.capture3(cli(cmd, oid, options))
        raise CommandError, err.chomp unless err.empty?
        out
      end

      # Generate a CLI command string
      def cli(command, id = nil, options = {})
        command = case command
                  when Symbol then "snmp#{command}"
                  else             command.to_s
                  end

        [
          command,
          *options.map { |k, v| "#{k}#{v}" },
          *@host_options.map { |k, v| "#{k}#{v}" },
          *id
        ].join(' ')
      end

      private

      def merge_options(options = {})
        options.each_pair.with_object({}) do |(key, value), opts|
          if OPTIONS.key?(key)
            opts[OPTIONS[key]] = value
          elsif key.is_a?(String)
            opts[key] = value
          else
            raise "Unknown option #{key}"
          end
        end
      end
    end # class CommandReader

    class CommandError < RuntimeError; end
  end # class Open
end # module SNMP
