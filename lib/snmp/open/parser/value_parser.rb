module SNMP
  class Open
    class Parser
      # base class for value parsers
      class ValueParser
        include SNMP::Open::Parser::Constants

        def self.find(type, token)
          cls = KNOWN_TOKENS[token] || KNOWN_TYPES[type] || Other
          cls.new(type, token)
        end

        def initialize(type, token)
          @type = type
          @token = token
        end

        def parse(*)
          @parse
        end

        # parses objects with no explicit type
        class Default < ValueParser
          def initialize(_type, token)
            @parse = ['STRING', token]
          end
        end # class Default

        # parses objects identified like '= Hex-STRING:'
        class HexString < ValueParser
          def parse(tokens)
            return @parse if @parse
            bytes = []
            loop do
              break unless tokens.peek =~ /\A[0-9A-Za-z]{2}\z/
              bytes << tokens.next
            end
            string = bytes.map { |b| b.to_i(16).chr }.join
            @parse = [@type, string]
          end
        end # class HexString

        # handles messages indicating the end of the response
        class Stop < ValueParser
          def parse(*)
            raise StopIteration, @token
          end
        end

        # handles objects not handled by any other parser
        class Other < ValueParser
          def parse(tokens)
            @parse ||= [@type, tokens.next]
          end
        end # class Other

        # handles NoSuchInstance
        class NoSuchInstance < ValueParser
          def initialize(*)
            @parse = ['No Such Instance', nil]
          end
        end # class NoSuchInstance < ValueParser

        # handles NoSuchObject
        class NoSuchObject < ValueParser
          def initialize(*)
            @parse = ['No Such Object', nil]
          end
        end # class NoSuchObject < ValueParser

        KNOWN_TOKENS = {
          NOSUCHINSTANCE_STR => NoSuchInstance,
          NOSUCHOBJECT_STR =>  NoSuchObject,
          NOMOREVARIABLES_STR => Stop
        }.freeze

        KNOWN_TYPES = {
          nil => Default,
          'Hex-STRING' => HexString
        }.freeze
      end # class ValueParser
    end # class Parser
  end # class Open
end # module SNMP
