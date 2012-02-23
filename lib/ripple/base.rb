#!/usr/bin/ruby
module Ripple
  require 'fileutils'
  require 'yaml'
  require "rubygems"
  require 'dropbox_sdk'

  ACCESS_TYPE = :app_folder
  DefaultConfiguration = {
    :destinationDir => './test',
    :cleanDestination => false,
    :dropbox => {
      :sync => ['**'],
    }
  }

  def Ripple.connectToDropbox
    #Load Dropbox API dropboxKeys from file, if applicable.
    if File.exists?('dropbox_session.yaml')
      dropboxKeys = YAML::load(File.read('dropbox_session.yaml'))
    else
      puts "A Dropbox API key/secret is required for accessing your sync files."
      puts "You can visit https://www.dropbox.com/developers/apps to generate these."
      puts "Please enter your Dropbox API key"
      dropboxKeys['key'] = gets.chomp!
      puts "Please enter your Dropbox API secret"
      dropboxKeys['secret'] = gets.chomp!
    end

    session = nil

    if dropboxKeys.has_key?(:session)
      session = DropboxSession.deserialize(dropboxKeys[:session])
    else
      session = DropboxSession.new(dropboxKeys[:key], dropboxKeys[:secret])
      session.get_request_token
      authorize_url = session.get_authorize_url
      puts "Visit #{authorize_url} to log in to Dropbox. Hit enter when you have done this."
      gets
      session.get_access_token
    end

    if session.nil?
      return nil, nil, nil
    end

    if !dropboxKeys.has_key?(:session)
      dropboxKeys[:session] = session.serialize()
    end

    client = DropboxClient.new(session, ACCESS_TYPE)

    if client.nil?
      return nil, nil, nil
    else
      return session, client, dropboxKeys
    end
  end

  def Ripple.loadConfiguration
    conf = Ripple::DefaultConfiguration.dup 

    # Load configuration and override any values that differ from the default.
    if File.exists?('ripple.yaml')
      loadedConf = YAML::load(File.read('ripple.yaml'))
      conf.merge!(loadedConf)
    end

    return conf
  end

  def Ripple.cleanup(conf, keys)
    File.open('dropbox_session.yaml', 'w') do|file|
      file.puts keys.to_yaml
    end

    File.open('ripple.yaml', 'w') do |file|
      file.puts conf.to_yaml
    end
  end

  def Ripple.sync
    conf = Ripple.loadConfiguration()
    session, client, dropboxKeys = Ripple.connectToDropbox()
   
    if session.nil?
      puts "Could not connect to Dropbox."
      Ripple.cleanup(conf, dropboxKeys)
    end 

    #Here we need to actually sync newest files.
    begin
      files = client.metadata('/', 10000, true, dropboxKeys[:files])
    rescue DropboxNotModified
      files = nil
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

    print files
  end
end
