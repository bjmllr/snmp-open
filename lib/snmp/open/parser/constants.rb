module SNMP
  class Open
    class Parser
      module Constants
        NOSUCHOBJECT_STR =
          'No Such Object available on this agent at this OID'.freeze
        NOSUCHINSTANCE_STR =
          'No Such Instance currently exists at this OID'.freeze
      end # module Constants
    end # class Parser
  end # class Open
end # module SNMP
