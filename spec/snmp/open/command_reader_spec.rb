require 'spec_helper'
require 'snmp/open/command_reader'

describe SNMP::Open::CommandReader do
  describe '#capture' do
    it 'chomps an error' do
      expect(Open3).to receive(:capture3)
        .with('blah -On -Ob -Oe -OU blah 1.0.1')
        .and_return(['', "ng\n"])
      expect do
        snmp = SNMP::Open::CommandReader.new(host: 'blah')
        snmp.capture('blah', '1.0.1')
      end.to raise_error(SNMP::Open::CommandError, 'ng')
    end

    it 'raises a precise error for a timeout' do
      expect(Open3).to receive(:capture3)
        .with('blah -On -Ob -Oe -OU blah 1.0.1')
        .and_return(['', 'Timeout: No Response from blah.'])
      expect do
        snmp = SNMP::Open::CommandReader.new(host: 'blah')
        snmp.capture('blah', '1.0.1')
      end.to raise_error(SNMP::Open::CommandTimeoutError,
                         'Timeout: No Response from blah.')
    end

    it 'raises a precise error on "Cannot find module"' do
      message =
        "MIB search path: /home/me/.snmp/mibs:/usr/share/mibs\n"\
        "Cannot find module (SNAPv2-MIB): At line 1 in (none)\n"\
        "SNAP-MIB::sysDescr: Unknown Object Identifier\n"

      expect(Open3).to receive(:capture3)
        .with('snmpbulkwalk -Ob -Oe -OU blah SNAPv2-MIB::sysDescr')
        .and_return(['', message])
      snmp = SNMP::Open::CommandReader.new(host: 'blah')

      expect do
        snmp.capture(:bulkwalk, 'SNAPv2-MIB::sysDescr')
      end.to raise_error(SNMP::Open::UnknownMIBError,
                         'Unknown MIB: SNAPv2-MIB')
    end

    it 'raises a precise error on "Unknown Object Identifier"' do
      message = "SNMPv2-MIB::sysDescl: Unknown Object Identifier\n"

      expect(Open3).to receive(:capture3)
        .with('snmpbulkwalk -Ob -Oe -OU blah SNMPv2-MIB::sysDescl')
        .and_return(['', message])
      snmp = SNMP::Open::CommandReader.new(host: 'blah')

      expect do
        snmp.capture(:bulkwalk, 'SNMPv2-MIB::sysDescl')
      end.to raise_error(SNMP::Open::UnknownOIDError,
                         'Unknown OID: SNMPv2-MIB::sysDescl')
    end

    it 'passes the env to the capture, if given' do
      expect(Open3).to receive(:capture3)
        .with({ 'EVAR' => 'VAL' }, 'blah -On -Ob -Oe -OU blah 1.0.1')
        .and_return(['', ''])
      snmp =
        SNMP::Open::CommandReader.new(host: 'blah', env: { 'EVAR' => 'VAL' })
      snmp.capture('blah', '1.0.1')
    end
  end

  describe '#cli' do
    let(:snmp) { SNMP::Open::CommandReader.new(host: 'example') }

    it 'returns the CLI command' do
      snmp = SNMP::Open::CommandReader.new(host: 'example')
      expect(snmp.cli(:bulkwalk)).to eq 'snmpbulkwalk -On -Ob -Oe -OU example'
    end

    it 'accepts a version option through the constructor' do
      snmp = SNMP::Open::CommandReader.new(host: 'example', version: '2c')
      expect(snmp.cli(:bulkwalk)).to eq 'snmpbulkwalk -On -Ob -Oe -OU -v2c example'
    end

    it 'accepts a user option using -u through the constructor' do
      snmp = SNMP::Open::CommandReader.new(host: 'example', '-u' => 'doe')
      expect(snmp.cli(:bulkwalk)).to eq 'snmpbulkwalk -On -Ob -Oe -OU -udoe example'
    end

    it 'accepts an object ID' do
      snmp = SNMP::Open::CommandReader.new(host: 'example')
      expect(snmp.cli(:bulkwalk, '1.2.3.4')).to eq 'snmpbulkwalk -On -Ob -Oe -OU example 1.2.3.4'
    end

    it 'includes -On without OID' do
      expect(snmp.cli(:walk)).to match(/ -On /)
    end

    it 'includes -On with numeric OID' do
      expect(snmp.cli(:walk, '1.2.3.4')).to match(/ -On /)
    end

    it 'omits -On with symbolic OID' do
      expect(snmp.cli(:walk, 'SNMPv2-MIB::sysDescr')).not_to match(/ -On /)
    end

    context 'for no_check_increasing' do
      let(:snmp) do
        SNMP::Open::CommandReader.new(host: 'example', no_check_increasing: true)
      end

      it 'includes -Cc for bulkwalk' do
        expect(snmp.cli(:bulkwalk, '1.2.3.4'))
          .to eq 'snmpbulkwalk -On -Ob -Oe -OU example -Cc 1.2.3.4'
      end

      it 'omits -Cc on get' do
        expect(snmp.cli(:get, '1.2.3.4'))
          .to eq 'snmpget -On -Ob -Oe -OU example 1.2.3.4'
      end

      it 'includes -Cc for walk' do
        expect(snmp.cli(:walk, '1.2.3.4'))
          .to eq 'snmpwalk -On -Ob -Oe -OU example -Cc 1.2.3.4'
      end
    end
  end # describe '#to_s' do
end # describe SNMP::Open::CommandReader do
