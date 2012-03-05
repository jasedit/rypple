#!/usr/bin/ruby

require 'fileutils'
require 'ftools'
require 'yaml'
require "rubygems"
require 'dropbox_sdk'
require 'pathname'
require 'require_all'

require_rel 'syncs/*.rb'

module Rypple

  DefaultConfiguration = {
      :syncs => [], 
      :generators => [],
  }
  RyppleConfigFile = "_rypple.yml"

  def self.sync path
    Rypple::load path

    @syncs.each do |sync|
      if sync.changes?
        sync.changes
      end
    end

    Rypple::save path
  end

  def self.load path
    @conf = Rypple::DefaultConfiguration.dup 

    rypple_conf = File.join(path, RyppleConfigFile)
    # Load configuration and override any values that differ from the default.
    if File.exists?(rypple_conf)
      conf = YAML::load(File.read(rypple_conf))
      @conf.merge!(conf)
    end

    @syncs = Array.new
    @conf[:sync].each do |ii|
      @syncs << Sync::create(ii[:name], ii)
    end

    #@generators = Array.new
    #conf[:generators].each do |key, value|
    #  @generators << 

  end

  def self.save path
    sync_configs = Array.new
    @syncs.each { |sync| sync_configs << sync.to_map }
    @conf[:syncs] = sync_configs

    #gen_configs = Array.new
    #@generators.each { |ii|
    ryppleConf = File.join(path, RyppleConfigFile)
    File.open(ryppleConf, 'w') do |file|
      file.puts conf.to_yaml
    end
  end
end
