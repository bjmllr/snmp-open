#!/usr/bin/env ruby

# Sample script

require 'bundler'
Bundler.setup
require 'json'
require 'snmp'
require 'snmp/open'
require 'rspec'

unless ENV.key?('SNMP_COMMUNITY')
  puts 'environment variable SNMP_COMMUNITY not set'
  exit 1
end

unless ENV.key?('SNMP_HOST')
  puts 'environment variable SNMP_HOST not set'
  exit 1
end

HOST = ENV['SNMP_HOST']

puts "Tests will run against #{HOST} using snmp and snmp-open"

snmp = SNMP::Manager.new(
  host: HOST,
  community: ENV['SNMP_COMMUNITY']
)

open = SNMP::Open.new(
  host: HOST,
  version: '2c',
  community: ENV['SNMP_COMMUNITY']
)

RSpec.describe SNMP::Open do
  context 'IF-MIB' do
    oids = [
      '1.3.6.1.2.1.47.1.1.1.1.7',     # ifname
      '1.3.6.1.4.1.9.9.91.1.1.1.1.1', # sensortype
      '1.3.6.1.4.1.9.9.91.1.1.1.1.4', # sensorval
      '1.3.6.1.4.1.9.9.91.1.1.1.1.5', # sensorstat
      '1.3.6.1.4.1.9.9.91.1.1.1.1.2'  # sensorscale
    ]

    snmp_walk = []
    snmp.walk(oids) do |*e|
      snmp_walk << e.map { |g| g.map { |v| SNMP.convert_from_snmp_to_ruby(v.value) } }
    end

    open_walk = []
    open.walk(oids) do |*e|
      open_walk << e.map { |g| g.map(&:value) }
    end

    it 'has the same first column' do
      expect(open_walk.map(&:first)).to eq snmp_walk.map(&:first)
    end

    it 'has the same first row' do
      expect(open_walk.first).to eq snmp_walk.first
    end

    it 'has the same rows and columns' do
      expect(open_walk).to eq snmp_walk
    end
  end

  context 'ENTITY-MIB' do
    oids = [
      '1.3.6.1.2.1.47.1.1.1.1.4',
      '1.3.6.1.2.1.47.1.1.1.1.7',
      '1.3.6.1.2.1.47.1.1.1.1.11',
      '1.3.6.1.2.1.47.1.1.1.1.12',
      '1.3.6.1.2.1.47.1.1.1.1.13',
      '1.3.6.1.4.1.9.9.92.1.1.1.5'
    ]

    snmp_walk = []
    snmp.walk(oids) do |*e|
      snmp_walk << e.map { |g| g.map { |v| SNMP.convert_from_snmp_to_ruby(v.value) } }
    end

    open_walk = []
    open.walk(oids) do |*e|
      open_walk << e.map { |g| g.map(&:value) }
    end

    it 'has the same first column' do
      expect(open_walk.map(&:first)).to eq snmp_walk.map(&:first)
    end

    it 'has the same first row' do
      expect(open_walk.first).to eq snmp_walk.first
    end

    it 'has the same rows and columns' do
      expect(open_walk).to eq snmp_walk
    end
  end
end # RSpec.describe SNMP::Open do
