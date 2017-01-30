require 'open3'
require 'snmp/open/parser'

# Simple Network Management Protocol
module SNMP
  # Converts types introduced by the snmp gem to native ruby types
  module_function def convert_from_snmp_to_ruby(value)
    return nil if [NoSuchInstance, NoSuchObject, Null].include?(value)

    case value
    when Integer
      value.to_i
    when IpAddress, String
      value.to_s
    else
      value
    end
  end

  # Open3-based wrapper for SNMP CLI commands
  class Open
    attr_reader :options

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
    # including all of the options listed in the +OPTIONS+ constant hash. Other
    # options can be given as strings (or any object with a suitable +to_s+
    # method), e.g., these are equivalent:
    #
    #   SNMP::Open.new(host: hostname, timeout: 3, '-m' => miblist)
    #   SNMP::Open.new(hostname => nil, '-t' => '3', '-m' => miblist)
    #
    def initialize(options = {})
      host = options.delete(:host) ||
             (raise ArgumentError, 'Host expected but not given')
      @host_options = merge_options(options)
                      .merge('-On' => nil, host => nil)
      return if @host_options.key?(nil)
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

    # Perform an SNMP get using the "snmpget" command and parse the output
    def get(oids)
      return enum_for(:get, oids) unless block_given?
      texts = oids.map { |oid| capture_command(:walk, oid) }
      Parser.new(oids).parse(texts).each { |arg, *| yield(arg) }
    end

    # Perform an SNMP walk using the "snmpwalk" or "snmpbulkwalk" commands and
    # parse the output
    def walk(oids, bulk: true, non_repeaters: 0, max_repetitions: 10)
      return enum_for(:walk, oids) unless block_given?
      cmd = bulk ? :bulkwalk : :walk
      options = bulk ? { '-Cn' => non_repeaters, '-Cr' => max_repetitions } : {}
      texts = oids.map { |oid| capture_command(cmd, oid, options) }
      Parser.new(oids).parse(texts).each { |*args| yield(*args) }
    end

    private

    def capture_command(cmd, oid, options = {})
      out, err = Open3.capture3(cli(cmd, oid, options))
      raise err unless err.empty?
      out
    end

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
  end # class Open
end # module SNMP
