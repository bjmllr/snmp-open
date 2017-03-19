require 'spec_helper'
require 'snmp/open/command_reader'

describe SNMP::Open::CommandReader do
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
  end # describe '#to_s' do
end # describe SNMP::Open::CommandReader do
