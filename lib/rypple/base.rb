#!/usr/bin/ruby
#  Copyright 2012 Jason Ziglar (jpz@rec.ri.cmu.edu)
#  Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#        http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

require 'fileutils'
require 'ftools'
require 'yaml'
require 'dropbox_sdk'
require 'pathname'
require 'require_all'

require_rel 'syncs/*.rb'
require_rel 'builders/*.rb'

module Rypple

  DefaultConfiguration = {
      :syncs => [], 
      :builders => [],
  }
  RyppleConfigFile = "_rypple.yml"

  def self.sync path
    Rypple::load path

    change_list = Array.new
    @syncs.each do |sync|
      if sync.changes?
        change_list.concat(sync.changes)
      end
    end

    change_list.each do |xx|
      xx.apply path
    end

    @syncs.each do |sync|
      sync.save change_list
    end

    @builders.each do |builder|
      builder.process_directory path
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
    @conf[:syncs].each do |ii|
      @syncs << Object.const_get(ii[:name]).new(path, ii)
    end

    #Instantiate all builders for use.
    @builders = Array.new
    @conf[:builders].each do |ii|
      @builders <<  Object.const_get(ii[:name]).new(ii)
    end
  end

  def self.save path
    sync_configs = Array.new
    @syncs.each { |sync| sync_configs << sync.to_map }
    @conf[:syncs] = sync_configs

    #gen_configs = Array.new
    #@generators.each { |ii|
    ryppleConf = File.join(path, RyppleConfigFile)
    File.open(ryppleConf, 'w') do |file|
      file.puts @conf.to_yaml
    end
  end
end
