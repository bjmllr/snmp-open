require 'snmp/open/parser'
require 'snmp/open/command_reader'

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
    attr_reader :reader

    # see CommandReader for a description of options
    def initialize(options = {})
      @reader = options[:reader] || CommandReader.new(options)
    end

    # Perform an SNMP get using the "snmpget" command and parse the output
    def get(oids)
      return enum_for(:get, oids) unless block_given?
      texts = oids.map { |oid| reader.capture(:get, oid) }
      Parser.new(oids).parse(texts).first.each { |arg| yield(arg) }
    end

    # Perform an SNMP walk using the "snmpwalk" or "snmpbulkwalk" commands and
    # parse the output
    def walk(oids, **kwargs)
      return enum_for(:walk, oids, **kwargs) unless block_given?
      bulk = kwargs.fetch(:bulk, true)
      options = walk_options(bulk, **kwargs)
      cmd = bulk ? :bulkwalk : :walk
      texts = oids.map { |oid| reader.capture(cmd, oid, options) }
      Parser.new(oids).parse(texts).each { |*args| yield(*args) }
    end

    def walk_options(bulk, **kwargs)
      if bulk
        {
          '-Cn' => kwargs.fetch(:non_repeaters, 0),
          '-Cr' => kwargs.fetch(:max_repetitions, 10)
        }
      else
        {}
      end
    end
  end # class Open
end # module SNMP
