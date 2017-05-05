# SNMP::Open

[![Gem Version](https://badge.fury.io/rb/snmp-open.svg)](https://rubygems.org/gems/snmp-open)
[![Build Status](https://travis-ci.org/bjmllr/snmp-open.svg)](https://travis-ci.org/bjmllr/snmp-open)

Ruby wrapper for the Net-SNMP command line programs `snmpget`, `snmpwalk`, and `snmpbulkwalk`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'snmp-open'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install snmp-open

## Usage

The API is very loosely based on that of the [snmp](https://github.com/hallidave/ruby-snmp) gem. `SNMP::Open` supports `#get` and `#walk` methods, which map to `snmpget` and `snmpbulkwalk`. These commands must be installed and available in the path.

Short command-line flags understood by `snmpcmd(1)` can be passed to the constructor directly:

```ruby
snmp = SNMP::Open.new(host: 'example1', '-v' => '2c', '-c' => ENV['COMMUNITY'])
snmp.walk(['1.3.6.1.2.1.47.1.1.1.1.7', '1.3.6.1.2.1.2.2.1.2']) do |name, descr|
  puts "Interface Name: #{name.value}, Description: #{descr.value}"
end
```

Naturally, configuration can also be supplied through `snmp.conf(5)`.

Environment variables can be given using the `env` keyword parameter to `SNMP::Open.new`. For example, the `SNMP_PERSISTENT_FILE` and `SNMPCONFPATH` variables are understood by Net-SNMP commands and indicate paths in which to look for configuration files.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bjmllr/snmp-open. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.
