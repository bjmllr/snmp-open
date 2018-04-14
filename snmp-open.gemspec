lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'snmp/open/version'

Gem::Specification.new do |spec|
  spec.name          = 'snmp-open'
  spec.version       = SNMP::Open::VERSION
  spec.authors       = ['Ben Miller']
  spec.email         = ['bmiller@rackspace.com']

  spec.summary       = 'Wrapper for command-line SNMP utilities'
  spec.homepage      = 'https://github.com/bjmllr/snmp-open'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'snmp'
end
