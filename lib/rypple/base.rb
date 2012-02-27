#!/usr/bin/ruby
module Rypple
  require 'fileutils'
  require 'ftools'
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

  DropboxKeyFile = "dropbox_session.yaml"
  RyppleConfigFile = "rypple.yaml"

  def Rypple.connectToDropbox(path)
    dropConf = File.join(path, DropboxKeyFile)
    #Load Dropbox API dropboxKeys from file, if applicable.
    if File.exists?(dropConf)
      dropboxKeys = YAML::load(File.read(dropConf))
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

  def Rypple.loadConfiguration(path)
    conf = Rypple::DefaultConfiguration.dup 

    rypConf = File.join(path, RyppleConfigFile)
    # Load configuration and override any values that differ from the default.
    if File.exists?(rypConf)
      loadedConf = YAML::load(File.read(rypConf))
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

  def Rypple.cleanup(conf, keys, path)
    dropConfig = File.join(path, DropboxKeyFile)
    File.open(dropConfig, 'w') do|file|
      file.puts keys.to_yaml
    end

    ryppleConf = File.join(path, RyppleConfigFile)
    File.open(ryppleConf, 'w') do |file|
      file.puts conf.to_yaml
    end
  end

  # Iterates over dropbox directory, returing paths and state hash for each file
  # oldFileState should be a hash of paths to state hashes, same as return values
  def Rypple.walkDropbox(client, path, fileState, oldFileState)
    #Here we need to actually sync newest files.
    begin
      useState = (!oldFileState.nil? and oldFileState.has_key?(path) and oldFileState[path]["path"] == path)
      oldState = useState ? oldFileState[path]["hash"] : nil
      states = client.metadata(path, 10000, true, oldState)
    rescue DropboxNotModified
      puts "Files have not changed."
      return nil
    end

    files = {}
    #State represents a folder
    if states["is_dir"] and states.has_key?("contents")
      states["contents"].each{ |xx|
        useState = (!oldFileState.nil? and oldFileState.has_key?(xx["path"]))
        old = (useState ? oldFileState[xx["path"]] : nil)
        subs = Rypple.walkDropbox(client, xx["path"], fileState, old)
        if !subs.nil?
          files.merge!(subs)
        end
      }
    else
      files[states['path']] = states
    end
    
    return files
  end

  def Rypple.sync(path = "")
    conf = Rypple.loadConfiguration(path)
    begin
      session, client, dropboxKeys = Rypple.connectToDropbox(path)
    rescue DropboxAuthError
      puts "Dropbox authorization failed."
      Rypple.cleanup(conf, dropboxKeys, path)
      return
    rescue NameError
      puts "Destination does not exist."
      Rypple.cleanup(conf, dropboxKeys, path)
      return
    end
   
    if session.nil?
      puts "Could not connect to Dropbox."
      Rypple.cleanup(conf, dropboxKeys, path)
      return
    end 

    destDir = conf[:destinationDir]

    fileState = {}
    oldFileState = dropboxKeys[:files]
    files = Rypple.walkDropbox(client, '/', fileState, oldFileState)

    if !files.nil?
      files.keys.each { |x|
        file = client.get_file(x)
        dest = File.join(destDir, x)
        File.makedirs(File.dirname(dest))
        File.open(dest, 'w') {|f| f.puts file}
      }
    end

    conf[:dropbox][:sync].each { |ii|
      Dir.glob(File.join(destDir, ii)).each { |oo|
        if !File.directory?(oo)
          upName = Pathname.new(oo).relative_path_from(Pathname.new(destDir)).to_s
          upName = File.join("", upName)
          if files.nil? or !files.has_key?(upName)
            up = File.open(oo)
            client.put_file(upName, up, true)
            up.close()
          end
        end
      }
    }

    dropboxKeys[:files] = Rypple.walkDropbox(client, '/', fileState, {})
    Rypple.cleanup(conf, dropboxKeys, path)

    return true
  end
end
