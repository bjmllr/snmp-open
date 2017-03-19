require 'snmp/open/command_reader'

module SNMP
  class Open
    # Test data source for SNMP::Open that reads from the filesystem instead of
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
        @command_generator =
          SNMP::Open::CommandReader.new(options.merge(host: '$OPTIONS'))
      end

      def capture(cmd, oid, _options = {})
        outfile = File.join(cmd.to_s, oid)
        File.read(File.join(@directory, outfile))
      rescue Errno::ENOENT => err
        warn "#{@command_generator.cli(cmd, oid)} > #{outfile}" if @warnings
        raise err
      end
    end # class FileReader
  end # class Open
end # module SNMP
