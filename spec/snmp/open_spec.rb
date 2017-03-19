require 'spec_helper'

describe SNMP::Open do
  describe '.new' do
    it 'raises when no host is given' do
      expect { SNMP::Open.new(version: '2c', timeout: 3) }
        .to raise_error(/Host expected/)
    end
  end # describe 'new' do

  describe '#walk' do
    let(:oids) { objects.map { |o| o[:oid] } }
    let(:values) { objects.map { |o| o[:value] } }
    let(:snmp) { SNMP::Open.new(host: 'example') }
    let(:walks) { snmp.walk(oids).to_a }

    let(:observed_values) do
      walks.map { |r| r.map(&:value) }
    end

    before do
      objects.each do |object|
        expect(Open3)
          .to receive(:capture3)
          .with("snmpbulkwalk -Cn0 -Cr10 -On example #{object[:oid]}")
          .and_return([object[:value], ''])
      end
    end

    context 'single row' do
      let(:objects) do
        [
          {
            oid: '1.3.6.1.2.1.1.1',
            value: ".1.3.6.1.2.1.1.1.0 = STRING: \"ACME AOS Software, a1b23 Software (a1b23-K9-D), Version 11.1(1)AA1, RELEASE SOFTWARE (fc4)\r\nCopyright (c) 1999-2011 by ACME, Inc.\r\nCompiled Tue 01-Jan-11 11:11\"\n"
          }, {
            oid: '1.3.6.1.2.1.1.4',
            value: ".1.3.6.1.2.1.1.4.0 = No Such Object available on this agent at this OID\n"
          }, {
            oid: '1.3.6.1.2.1.1.5',
            value: ".1.3.6.1.2.1.1.5.0 = STRING: \"router1\"\n"
          }, {
            oid: '1.3.6.1.2.1.1.6',
            value: ".1.3.6.1.2.1.1.6.0 = \"\"\n"
          }, {
            oid: '1.3.6.1.2.1.1.7',
            value: ".1.3.6.1.2.1.1.7.0 = No Such Instance currently exists at this OID\n"
          }
        ]
      end

      it 'creates an entry for each OID given' do
        walks.each do |row|
          oids.zip(row).each do |oid, object|
            expect(object.oid).to start_with(oid)
          end
        end
      end

      it 'gives the type of each value' do
        expect(walks.flatten(1).map(&:type))
          .to eq ['STRING', 'No Such Object', 'STRING', 'STRING', 'No Such Instance']
      end

      it 'extracts multiline strings' do
        expect(walks[0][0].value).to match(/Compiled Tue/)
        expect(walks[0][0].value.lines.size).to eq 3
      end

      it 'converts NoSuchObject responses' do
        expect(walks[0][1].type).to eq 'No Such Object'
        expect(walks[0][1].value).to be_nil
      end

      it 'extracts quoted strings' do
        expect(walks[0][2].value).to eq 'router1'
        expect(walks[0][3].value).to eq ''
      end

      it 'converts NoSuchInstance responses' do
        expect(walks[0][4].type).to eq 'No Such Instance'
        expect(walks[0][4].value).to be_nil
      end
    end # context 'SYSTEM-MIB' do

    context 'one column is unavailable' do
      let(:objects) do
        [
          {
            oid: '1.3.6.1.2.1.47.1.1.1.1.4',
            value: <<-END.lstrip_lines
              .1.3.6.1.2.1.47.1.1.1.1.4.1001 = INTEGER: 0
              .1.3.6.1.2.1.47.1.1.1.1.4.1002 = INTEGER: 1001
              .1.3.6.1.2.1.47.1.1.1.1.4.1003 = INTEGER: 1001
            END
          }, {
            oid: '1.3.6.1.2.1.47.1.1.1.1.7',
            value: <<-END.lstrip_lines
              .1.3.6.1.2.1.47.1.1.1.1.7.1001 = STRING: "1"
              .1.3.6.1.2.1.47.1.1.1.1.7.1002 = STRING: "WS-C2960-24TT-L - Fixed Module 0"
              .1.3.6.1.2.1.47.1.1.1.1.7.1003 = STRING: "WS-C2960-24TT-L - Power Supply 0"
            END
          }, {
            oid: '1.3.6.1.4.1.9.9.92.1.1.1.5',
            value: <<-END.lstrip_lines
              .1.3.6.1.4.1.9.9.92.1.1.1.5 = No Such Object available on this agent at this OID
            END
          }
        ]
      end

      let(:expected_values) do
        [
          [0, '1', nil],
          [1001, 'WS-C2960-24TT-L - Fixed Module 0', nil],
          [1001, 'WS-C2960-24TT-L - Power Supply 0', nil]
        ]
      end

      it 'uses the indexes of the first column as the row indexes' do
        expect(observed_values).to eq expected_values
      end
    end # context 'missing column' do
  end # describe '#walk' do
end # describe SNMP::Open do
