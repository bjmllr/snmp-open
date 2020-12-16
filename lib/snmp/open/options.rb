module SNMP
  class Open
    class Options
      # see snmpcmd(1) for explanation of options
      MAP = {
        version: '-v',
        auth_password: '-A',
        auth_protocol: '-a',
        community: '-c',
        context: '-n',
        no_check_increasing: {
          'snmpbulkwalk' => '-Cc',
          'snmpwalk' => '-Cc'
        },
        no_units: '-OU',
        non_symbolic: '-Oe',
        numeric: '-On',
        priv_password: '-X', # not recommended, see snmp.conf(5)
        priv_protocol: '-x',
        sec_level: '-l',
        sec_user: '-u',
        retries: '-r',
        timeout: '-t',
        host: nil
      }.freeze

      # On some systems, SNMP command outputs will include symbolic values
      # and/or value units. The parser doesn't support these, so disable them.
      REQUIRED_BY_PARSER = {
        '-Oe' => nil,
        '-OU' => nil
      }.freeze

      VALUES = {
        no_check_increasing: {
          true => ''
        }.freeze
      }.freeze
    end # class Options
  end # class Open
end # module SNMP
