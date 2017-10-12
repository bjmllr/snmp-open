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

      def initialize(oids)
        @oids = oids
      end

      def parse(texts)
        columns = texts.map do |text|
          tokenized =
            text
            .gsub(NOSUCHOBJECT_STR, %("#{NOSUCHOBJECT_STR}"))
            .gsub(NOSUCHINSTANCE_STR, %("#{NOSUCHINSTANCE_STR}"))
            .gsub(NOMOREVARIABLES_STR, %("#{NOMOREVARIABLES_STR}"))
            .shellsplit
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
        return objects
      end

      def parse_next_object(tokens)
        oid = tokens.next.sub(/\A\./, '')
        raise "Parse error at #{oid}" unless oid =~ /\A[0-9.]+\z/
        equals = tokens.next
        raise "Parse error after #{oid}" unless equals == '='
        type, value = parse_type(tokens)
        Value.new(oid, type, value)
      end

      def parse_type(tokens)
        next_token = tokens.next
        raise StopIteration, next_token if next_token == NOMOREVARIABLES_STR
        type = next_token.match(/\A([-A-Za-z]+):\z/) { |md| md[1] }
        type, value = parse_value(tokens, next_token, type)
        [type, Conversions.convert_value(type, value)]
      end

      def parse_value(tokens, token, type)
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
            column.find { |o| o.oid == id } || Conversions.absent_value(id)
          end
        end
      end

      # functions to generate value objects
      module Conversions
        module_function def convert_value(type, value)
          case type
          when 'INTEGER'
            value.to_i
          else
            value
          end
        end

        module_function def absent_value(id)
          Value.new(id, 'absent', nil)
        end
      end
    end # class Parser
  end # class Open
end # module SNMP
