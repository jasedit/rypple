#!/usr/bin/ruby
module Ripple
  require 'fileutils'
  require 'yaml'
  require "rubygems"
  require 'dropbox_sdk'

  ACCESS_TYPE = :app_folder
  DefaultConfiguration = {
    :destinationDir => './test',
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

  def Ripple.walkDropbox(client, path, fileState, oldFileState)
    #Here we need to actually sync newest files.
    areNewFiles = false
    begin
      oldState = oldFileState.has_key?(path) ? oldFileState[path] : nil
      fileState[path] = client.metadata(path, 10000, true, oldState)
      areNewFiles = true
    rescue DropboxNotModified
      if oldFileState.has_key?(path)
        fileState[path] = oldFileState[path]
      end
    end

    if !areNewFiles
      return nil
    end

    files = []
    if fileState[path]["is_dir"] and fileState[path].has_key?("contents")
      fileState[path]["contents"].each { |x|
        subs = Ripple.walkDropbox(client, x["path"], fileState, oldFileState)
        if !subs.nil?
          files = files + subs
        end
      }
    else
      files = [fileState[path]["path"]]
    end

    return files
  end

  def Ripple.sync
    conf = Ripple.loadConfiguration()
    begin
      session, client, dropboxKeys = Ripple.connectToDropbox()
    rescue DropboxAuthError
      puts "Dropbox authorization failed."
      Ripple.cleanup(conf, dropboxKeys)
      return
    end
   
    if session.nil?
      puts "Could not connect to Dropbox."
      Ripple.cleanup(conf, dropboxKeys)
      return
    end 

    destDir = conf[:destinationDir]

    fileState = {}
    oldFileState = {}
    files = Ripple.walkDropbox(client, '/', fileState, oldFileState)
    p files

    Ripple.cleanup(conf, dropboxKeys)
  end
end
