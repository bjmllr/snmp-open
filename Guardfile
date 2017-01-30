group :ruby, halt_on_fail: true do
  guard :rspec,
        all_on_start: true,
        run_all: { cmd: 'bundle exec rspec -f p' },
        cmd: 'bundle exec rspec -f d --fail-fast' do
    require 'guard/rspec/dsl'
    dsl = Guard::RSpec::Dsl.new(self)

    # RSpec files
    rspec = dsl.rspec
    watch(rspec.spec_helper) { rspec.spec_dir }
    watch(rspec.spec_support) { rspec.spec_dir }
    watch(rspec.spec_files)

    # Ruby files
    ruby = dsl.ruby
    dsl.watch_spec_files_for(ruby.lib_files)
  end

  guard :rubocop, cli: ['-aD'] do
    watch(/Guardfile/)
    watch(/.+\.rb$/)
    watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
  end
end # group :ruby do
