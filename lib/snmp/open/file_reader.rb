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
      DEFAULT_WARNING_FORMATTER = lambda { |gen, cmd, oid, outfile|
        "#{gen.cli(cmd, oid)} > #{outfile}"
      }

      def initialize(directory, options = {})
        @directory = directory
        @warnings = options.delete(:warnings)
        @make_directories = options.delete(:make_directories)
        if @warnings && !@warnings.respond_to?(:call)
          @warnings = DEFAULT_WARNING_FORMATTER
        end
        options[:host] ||= '$OPTIONS'
        @command_generator = SNMP::Open::CommandReader.new(options)
      end

      def capture(cmd, oid, _options = {})
        mkdir(@directory, cmd.to_s) if @make_directories
        outfile = File.join(@directory, cmd.to_s, oid)
        File.read(outfile)
      rescue Errno::ENOENT => e
        if @warnings
          warning = @warnings.call(@command_generator, cmd, oid, outfile)
          warn warning
        end
        raise e
      end

      def mkdir(base, cmd)
        Dir.mkdir(base) unless File.exist?(base)
        Dir.mkdir(File.join(base, cmd)) unless File.exist?(File.join(base, cmd))
      end
    end # class FileReader
  end # class Open
end # module SNMP
