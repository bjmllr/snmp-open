require 'snmp/open/parser'

module SNMP
  class Open
    # Test double for SNMP::Open that reads from the filesystem instead of
    # running SNMP commands. Expects a 'walk' directory to be present if #walk
    # will be used, and a 'get' directory if #get will be used. Within each
    # directory, files named according to the numeric OIDs to be used are
    # expected to be present, containing the output of an snmpwalk or snmpget
    # run over the given OID.
    #
    # Produces warnings describing an snmpbulkwalk or snmpget command that could
    # be used to generate a needed file, if the file is unavailable. Controlled
    # by the `warnings` option.

    class FileReader
      def initialize(directory, options = {})
        @directory = directory
        @warnings = options.delete(:warnings)
        @command_generator = SNMP::Open.new(options.merge(host: '$OPTIONS'))
      end

      def get(oids)
        return enum_for(:get, oids) unless block_given?
        texts = oids.map { |o| File.read(File.join(@directory, 'get', o)) }
        Parser.new(oids).parse(texts).each { |arg, *| yield(arg) }
      rescue Errno::ENOENT => err
        if @warnings
          oids.each do |oid|
            warn "#{@command_generator.cli(:get, oid)} > get/#{oid}"
          end
        end
        raise err
      end

      def walk(oids, *rest)
        return enum_for(:walk, oids, *rest) unless block_given?
        texts = oids.map { |o| File.read(File.join(@directory, 'walk', o)) }
        Parser.new(oids).parse(texts).each { |*args| yield(*args) }
      rescue Errno::ENOENT => err
        if @warnings
          oids.each do |oid|
            warn "#{@command_generator.cli(:bulkwalk, oid)} > walk/#{oid}"
          end
        end
        raise err
      end
    end # class FileReader
  end # class Open
end # module SNMP
