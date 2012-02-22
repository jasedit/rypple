#!/usr/bin/ruby
module Ripple
require 'fileutils'
require 'yaml'
require "rubygems"
require 'dropbox_sdk'

ACCESS_TYPE = :app_folder
def sync()
conf = {:destinationDir => './test',
        :cleanDestiation => false}

# Load configuration.
if File.exists?('ripple.yaml')
  conf = YAML::load(File.read('ripple.yaml'))
end

#Load Dropbox API login from file, if applicable.
if File.exists?('keys.yaml')
  login = YAML::load(File.read('keys.yaml'))
else
  puts "Please enter your Dropbox API key"
  login['key'] = gets.chomp!
  puts "Please enter your Dropbox API secret"
  login['secret'] = gets.chomp!
end

if !conf.has_key?(:destinationDir)
  conf[:destinationDir] = './test'
end

destDir = conf[:destinationDir]

if conf.has_key?(:cleanDestination)
  if conf[:cleanDestination]
    files = Dir.glob(destDir + "**")

    if files.empty?
      FileUtils.rm(files)
    end
  end
end

session = nil

if File.exists?('dropbox_session.yaml')
  deser = File.open('dropbox_session.yaml').read
  session = DropboxSession.deserialize(deser)
else
  session = DropboxSession.new(login[:key], login[:secret])
  session.get_request_token
  authorize_url = session.get_authorize_url
  puts "Visit #{authorize_url} to log in to Dropbox. Hit enter when you have done this."
  gets
  session.get_access_token
end

if session == nil
  exit
end
client = DropboxClient.new(session, ACCESS_TYPE)

#Here we need to actually sync newest files.
puts client.metadata('/')

File.open('dropbox_session.yaml', 'w') do|file|
  file.puts session.serialize()
end

File.open('ripple.yaml', 'w') do |file|
  file.puts conf.to_yaml
end
end
end
