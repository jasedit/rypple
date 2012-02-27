#!/usr/bin/ruby
module Ripple
  require 'fileutils'
  require 'yaml'
  require "rubygems"
  require 'dropbox_sdk'
  require 'pathname'

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

    conf[:destinationDir] = File.expand_path(conf[:destinationDir])
    if !File.directory?(conf[:destinationDir])
      begin
        Dir.mkdir(conf[:destinationDir])
      rescue SystemCallError
        raise RuntimeError, "Destination doesn't exist and cannot be created."
      end
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

  # Iterates over dropbox directory, returing paths and state hash for each file
  # oldFileState should be a hash of paths to state hashes, same as return values
  def Ripple.walkDropbox(client, path, fileState, oldFileState)
    #Here we need to actually sync newest files.
    begin
      useState = (!oldFileState.nil? and oldFileState.has_key?(path) and oldFileState[path]["path"] == path)
      oldState = useState ? oldFileState[path]["hash"] : nil
      states = client.metadata(path, 10000, true, oldState)
    rescue DropboxNotModified
      puts "Files have not changed."
      return nil
    end

    files = { states["path"] => states }
    #State represents a folder
    if states["is_dir"] and states.has_key?("contents")
      states["contents"].each{ |xx|
        if !xx.nil?
          files[xx["path"]] = xx
        end
        useState = (!oldFileState.nil? and oldFileState.has_key?(xx["path"]))
        old = (useState ? oldFileState[xx["path"]]["hash"] : nil)
        subs = Ripple.walkDropbox(client, xx["path"], fileState, old)
        if !subs.nil?
          files.merge!(subs)
        end
      }
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
    rescue NameError
      puts "Destination does not exist."
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
    oldFileState = dropboxKeys[:files]
    files = Ripple.walkDropbox(client, '/', fileState, oldFileState)

    if files.nil?
      files = oldFileState
      Ripple.cleanup(conf, dropboxKeys)
    else
      files.keys.each { |x|
        puts "Getting", x
        file = client.get_file(x)
        File.open(File.join(destDir, x), 'w') {|f| f.puts file}
      }
    end

    conf[:dropbox][:sync].each { |ii|
      Dir.glob(File.join(destDir, ii)).each { |oo|
        if !File.directory?(oo)
          up = File.open(oo)
          upName = Pathname.new(oo).relative_path_from(Pathname.new(destDir)).to_s
          upName = File.join("", upName)
          if files.nil? or !files.has_key?(upName)
            puts "Sending", upName
            client.put_file(upName, up, true)
          end
        end
      }
    }

    dropboxKeys[:files] = Ripple.walkDropbox(client, '/', fileState, {})
    Ripple.cleanup(conf, dropboxKeys)

    return true
  end
end
