require 'set'
require 'shellwords'
require 'snmp/open/parser/constants'
require 'snmp/open/parser/value_parser'

module SNMP
  class Open
    Value = Struct.new(:oid, :type, :value) do
      def id_after(path)
        oid.sub(/^#{path}\./, '') if oid.start_with?(path)
      end
    end

    # convert SNMP command output into arrays
    class Parser
      include SNMP::Open::Parser::Constants
      OID_RE = Regexp.union(/\S+-MIB::\S+/, /[0-9.]+/)
      EMPTY_STRING_RE = /^(#{OID_RE})\s+=\s+(Opaque|STRING):\s*\n/.freeze
      STRING_RE = /^(#{OID_RE})\s+=\s+(Opaque|STRING):\s+((?!")[^\n]*(\n(?!#{OID_RE}\s+=\s+)[^\n]+)*)\n/.freeze

      def initialize(oids)
        @oids = oids
      end

      def parse(texts)
        columns = texts.map do |text|
          clean = clean_input_text(text)
          tokenized = clean.shellsplit
          parse_tokens(tokenized)
        end

        table(columns)
      end

      private

      def align(columns)
        indexes = columns.first.map { |value| index_using_first_oid(value) }
        hash = columns.flat_map { |row| row.map { |v| [v.oid, v] } }.to_h

        indexes.map do |index|
          @oids.map do |base|
            oid = [base, *index].join('.')
            hash.fetch(oid) { Value.new(oid, 'absent', nil) }
          end
        end
      end

      def clean_input_text(text)
        text
          .gsub(/\r\n|\n\r|\r/, "\n")
          .gsub(EMPTY_STRING_RE, %(\\1 = \\2: ""\n))
          .gsub(STRING_RE, %(\\1 = \\2: "\\3"\n))
          .gsub(Static::ANY_MESSAGE, Static::QUOTED_MESSAGES)
      end

      def index_using_first_oid(value)
        base = @oids.first

        if base == value.oid
          nil
        elsif value.oid.start_with?(base)
          value.oid.gsub(/\A#{base}\.?/, '')
        else
          raise "Received ID doesn't start with the given ID"
        end
      end

      def parse_tokens(tokens)
        tokens = tokens.each
        objects = []

        loop do
          objects << parse_next_object(tokens)
        end

        objects
      rescue StopIteration
        objects
      end

      def parse_next_object(tokens)
        oid = tokens.next.sub(/\A\./, '')
        raise "Parse error at #{oid}" unless oid =~ OID_RE

        equals = tokens.next
        raise "Parse error after #{oid}" unless equals == '='

        type, value = parse_type(tokens)
        Value.new(oid, type, value)
      end

      def parse_type(tokens)
        token = tokens.next
        type = token.match(/\A([-A-Za-z]+[0-9]*):\z/) { |md| md[1] }
        ValueParser.find(type, token).parse(tokens)
      end

      def table(columns)
        if columns.size == 1 && columns.all? { |column| column.size == 1 }
          columns
        else
          align(columns)
        end
      end

      def indexes(columns)
        indexes = SortedSet.new
        @oids.zip(columns).each do |oid, column|
          column.each do |item|
            index = item.id_after(oid)
            indexes << index if index
          end
        end
        indexes
      end

      def fill_gaps(columns)
        indexes = indexes(columns)
        @oids.zip(columns).map do |oid, column|
          indexes.map do |index|
            id = (oid == index ? index : "#{oid}.#{index}")
            column.find { |o| o.oid == id } || Value.new(id, 'absent', nil)
          end
        end
      end

      # static messages from net-snmp commands
      module Static
        include SNMP::Open::Parser::Constants

        MESSAGES = [
          NOSUCHOBJECT_STR,
          NOSUCHINSTANCE_STR,
          NOMOREVARIABLES_STR
        ].freeze

        ANY_MESSAGE = Regexp.union(*MESSAGES)

        QUOTED_MESSAGES = MESSAGES.map { |v| [v, %("#{v}")] }.to_h.freeze
      end
    end # class Parser
  end # class Open
end # module SNMP
