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

      EMPTY_STRING_RE =
        /^(#{OID_RE})     # capture group 1: OID
          \s+=\s+
          (Opaque|STRING) # capture group 2: Type
          :\s*\n          # value is always empty string
        /x.freeze

      STRING_RE =
        /^(#{OID_RE})         # capture group 1: OID
          \s+=\s+
          (Opaque|STRING):\s+ # capture group 2: Type

          (                   # capture group 3: Value

           (?!")              # this pattern is for finding strings in need of
                              # quoting, so reject any strings that are already
                              # quoted

           [^\n]*             # first line of value

           (\n                # newline before each additional line of value
            (?!
             #{OID_RE}        # additional lines of value are identified by not
             \s+=\s+          # starting with "<OID> ="
            )
            [^\n]+            # additional lines of value
           )*
          )\n
        /x.freeze

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
        indexes = indexes_from_columns(columns)
        bases = bases_from_columns(columns)
        hash = columns.flat_map { |row| row.map { |v| [v.oid, v] } }.to_h

        indexes.map do |index|
          bases.map do |base, _|
            oid = [base, *index].join('.')
            hash.fetch(oid) { Value.new(oid, 'absent', nil) }
          end
        end
      end

      def bases_from_columns(columns)
        @oids
          .zip(columns.map { |c| c&.first&.oid })
          .map { |base, oid| base && oid && split_oid(base, oid) }
      end

      def clean_input_text(text)
        text
          .gsub(/\r\n|\n\r|\r/, "\n")
          .gsub(EMPTY_STRING_RE, %(\\1 = \\2: ""\n))
          .gsub(STRING_RE, %(\\1 = \\2: "\\3"\n))
          .gsub(Static::ANY_MESSAGE, Static::QUOTED_MESSAGES)
      end

      def indexes_from_columns(columns)
        columns.first.map { |value| split_oid(@oids.first, value.oid)[1] }
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

      # split a complete OID into a base and index, given an expected base
      # raises if the base isn't present
      def split_oid(base, oid)
        if base == oid
          [base, nil]
        elsif oid.start_with?(base)
          [base, oid.sub(/\A#{base}\.?/, '')]
        elsif base.include?('::') && !oid.include?('::')
          alternate_base = base.sub(/\A[^:]+::/, '')
          split_oid(alternate_base, oid)
        else
          raise "Received ID doesn't start with the given ID"
        end
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
