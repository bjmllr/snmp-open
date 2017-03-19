require 'spec_helper'
require 'snmp/open/command_reader'

describe SNMP::Open::CommandReader do
  describe '#capture' do
    it 'chomps an error' do
      expect(Open3).to receive(:capture3).with('blah -On blah blah')
        .and_return(['', "ng\n"])
      expect do
        snmp = SNMP::Open::CommandReader.new(host: 'blah')
        snmp.capture('blah', 'blah')
      end.to raise_error(SNMP::Open::CommandError, 'ng')
    end
  end

  describe '#cli' do
    it 'returns the CLI command' do
      snmp = SNMP::Open::CommandReader.new(host: 'example')
      expect(snmp.cli(:bulkwalk)).to eq 'snmpbulkwalk -On example'
    end

    it 'accepts a version option through the constructor' do
      snmp = SNMP::Open::CommandReader.new(host: 'example', version: '2c')
      expect(snmp.cli(:bulkwalk)).to eq 'snmpbulkwalk -v2c -On example'
    end

    it 'accepts a user option using -u through the constructor' do
      snmp = SNMP::Open::CommandReader.new(host: 'example', '-u' => 'doe')
      expect(snmp.cli(:bulkwalk)).to eq 'snmpbulkwalk -udoe -On example'
    end

    it 'accepts an object ID' do
      snmp = SNMP::Open::CommandReader.new(host: 'example')
      expect(snmp.cli(:bulkwalk, '1.2.3.4')).to eq 'snmpbulkwalk -On example 1.2.3.4'
    end

    context 'for no_check_increasing' do
      let(:snmp) do
        SNMP::Open::CommandReader.new(host: 'example', no_check_increasing: true)
      end

      it 'includes -Cc for bulkwalk' do
        expect(snmp.cli(:bulkwalk, '1.2.3.4'))
          .to eq 'snmpbulkwalk -On example -Cc 1.2.3.4'
      end

      it 'omits -Cc on get' do
        expect(snmp.cli(:get, '1.2.3.4'))
          .to eq 'snmpget -On example 1.2.3.4'
      end

      it 'includes -Cc for walk' do
        expect(snmp.cli(:walk, '1.2.3.4'))
          .to eq 'snmpwalk -On example -Cc 1.2.3.4'
      end
    end
  end # describe '#to_s' do
end # describe SNMP::Open::CommandReader do
