require 'spec_helper'

module SNMP
  class Open
    describe Parser do
      it 'parses an integer' do
        parser = Parser.new(['1.2.3'])
        texts = [".1.2.3.4 = INTEGER: 90\n"]
        parsed = parser.parse(texts)
        expect(parsed[0][0]).to eq Value.new('1.2.3.4', 'INTEGER', 90)
      end

      it 'parses a No Such Object response' do
        parser = Parser.new(['1.2.3'])
        texts = [".1.2.3.0 = No Such Object available on this agent at this OID\n"]
        parsed = parser.parse(texts)
        expect(parsed[0][0]).to eq Value.new('1.2.3.0', 'No Such Object', nil)
      end

      it 'parses BITS' do
        parser = Parser.new(['1.2.3'])
        texts = [".1.2.3.0 = BITS: 01 2 FF\n.1.2.3.4 = INTEGER: 90\n"]
        expected = [[Value.new('1.2.3.0', 'BITS', [1, 2, 255])],
                    [Value.new('1.2.3.4', 'INTEGER', 90)]]

        parsed = parser.parse(texts)
        expect(parsed.to_a).to eq expected
      end

      it 'parses a Counter32' do
        parser = Parser.new(['1.2.3'])
        texts = ['.1.2.3.0 = Counter32: 51']
        expected = [[Value.new('1.2.3.0', 'Counter32', 51)]]

        parsed = parser.parse(texts)
        expect(parsed.to_a).to eq expected
      end

      it 'parses an INTEGER' do
        parser = Parser.new(['1.2.3'])
        texts = ['.1.2.3.0 = INTEGER: 01']
        expected = [[Value.new('1.2.3.0', 'INTEGER', 1)]]

        parsed = parser.parse(texts)
        expect(parsed.to_a).to eq expected
      end

      it 'parses a Gauge32' do
        parser = Parser.new(['1.2.3'])
        texts = ['.1.2.3.0 = Gauge32: 15']
        expected = [[Value.new('1.2.3.0', 'Gauge32', 15)]]

        parsed = parser.parse(texts)
        expect(parsed.to_a).to eq expected
      end

      it 'parses a Hex-STRING' do
        parser = Parser.new(['1.2.3'])
        texts = [".1.2.3.0 = Hex-STRING: 41 56 4D 31 38 30 34 55 30 01\n"]
        expected = [[Value.new('1.2.3.0', 'Hex-STRING', "AVM1804U0\x01")]]

        parsed = parser.parse(texts)
        expect(parsed.to_a).to eq expected
      end

      it 'handles a single result with an unexpected OID' do
        parser = Parser.new(['1.2.3.4'])
        texts = [".1.2.3.9 = INTEGER: 1\n"]
        parsed = parser.parse(texts)
        expect(parsed).to eq [[Value.new('1.2.3.9', 'INTEGER', 1)]]
      end

      it 'handles an unquoted empty string' do
        parser = Parser.new(['1.2.3'])
        texts = [".1.2.3.1 = STRING: \n.1.2.3.4 = INTEGER: 1\n"]
        parsed = parser.parse(texts)
        expect(parsed.map { |e| e.first.value }).to eq ['', 1]
      end

      it 'handles an unquoted multi-word string' do
        parser = Parser.new(['1.2.3'])
        texts = [".1.2.3.1 = STRING: one two three\n.1.2.3.4 = INTEGER: 1\n"]
        parsed = parser.parse(texts)
        expect(parsed.map { |e| e.first.value }).to eq ['one two three', 1]
      end

      it 'handles multiline values' do
        texts = [".1.3.6.1.2.1.1.9.1.3.72 = STRING: \"Capabilities for ACME-SONET-MIB.\n\n\n      - acmeSonetAxsmCapability is for \n\n        ATM Switch Service Module(ASSM).\n\n\n\n      - acmeSonetAxsmCapabilityV2 is for \n\n        ATM Switch Service Module(ASSM).\n\n\n\n      - acmeSonet\"\n"]

        parser = Parser.new(['1.3.6.1.2.1.1.9.1.3.72'])
        parsed = parser.parse(texts)
        expect(parsed[0][0].value).to match(/ATM Switch Service Module/)
      end

      it 'handles no more variables response' do
        texts = [
          ".1.2.3 = INTEGER: 1\n"\
          ".1.2.3 = No more variables left in this MIB View (It is past the end of the MIB tree)\n"
        ]

        parser = Parser.new(['1.2.3'])
        parsed = parser.parse(texts)
        expect(parsed[0][0].value).to eq 1
      end

      it 'fills in missing entries with null values' do
        texts = [<<-ONE, <<-TWO, <<-THREE]
          .1.2.3.4.1 = "a"
          .1.2.3.4.2 = "b"
          .1.2.3.4.3 = "c"
          .1.2.3.4.4 = "d"
        ONE
          .1.2.3.5.1 = "p"
          .1.2.3.5.3 = "q"
        TWO
          .1.2.3.6.1 = "w"
          .1.2.3.6.2 = "x"
          .1.2.3.6.4 = "z"
        THREE

        parser = Parser.new(['1.2.3.4', '1.2.3.5', '1.2.3.6'])

        expectation = [
          [
            Value.new('1.2.3.4.1', 'STRING', 'a'),
            Value.new('1.2.3.5.1', 'STRING', 'p'),
            Value.new('1.2.3.6.1', 'STRING', 'w')
          ], [
            Value.new('1.2.3.4.2', 'STRING', 'b'),
            Value.new('1.2.3.5.2', 'absent', nil),
            Value.new('1.2.3.6.2', 'STRING', 'x')
          ], [
            Value.new('1.2.3.4.3', 'STRING', 'c'),
            Value.new('1.2.3.5.3', 'STRING', 'q'),
            Value.new('1.2.3.6.3', 'absent', nil)
          ], [
            Value.new('1.2.3.4.4', 'STRING', 'd'),
            Value.new('1.2.3.5.4', 'absent', nil),
            Value.new('1.2.3.6.4', 'STRING', 'z')
          ]
        ]

        expect(parser.parse(texts)).to eq expectation
      end
    end
  end # class Open
end # module SNMP
