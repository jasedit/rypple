#!/usr/bin/ruby
module Rypple
  require 'fileutils'
  require 'ftools'
  require 'yaml'
  require "rubygems"
  require 'dropbox_sdk'
  require 'pathname'

  DefaultConfiguration = {
    :destinationDir => './test',
    :dropbox => {
      :root => '/',
      :sync => ['**'],
      :access_type => :app_folder,
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
      print "Please enter your Dropbox API key:"
      dropboxKeys = {}
      dropboxKeys[:key] = gets.chomp!
      print "Please enter your Dropbox API secret:"
      dropboxKeys[:secret] = gets.chomp!
      print "Should this API access be used in sandbox mode? (Y/n):"
      answer = gets.downcase.chomp
      if !answer.empty? and answer == 'n'
        dropboxKeys[:access_type]= :dropbox
      end
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

    client = DropboxClient.new(session, dropboxKeys[:access_type])

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

  def Rypple.saveDropbox(keys, path)
    dropConfig = File.join(path, DropboxKeyFile)
    File.open(dropConfig, 'w') do|file|
      file.puts keys.to_yaml
    end
  end

  def Rypple.saveConfig(conf, path)
    ryppleConf = File.join(path, RyppleConfigFile)
    File.open(ryppleConf, 'w') do |file|
      file.puts conf.to_yaml
    end
  end

  def Rypple.cleanup(conf, keys, path)
    Rypple.saveConfig(conf, path)
    Rypple.saveDropbox(keys, path)
  end

  # Iterates over dropbox directory, returing paths and state hash for each file
  # oldFileState should be a hash of paths to state hashes, same as return values
  def Rypple.walkDropbox(client, path, oldFileState)
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
        subs = Rypple.walkDropbox(client, xx["path"], old)
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

    oldFileState = dropboxKeys[:files]
    files = Rypple.walkDropbox(client, conf[:dropbox][:root], oldFileState)

    rootLength = conf[:dropbox][:root].length
    if !files.nil?
      files.keys.each { |xx|
        fileDest = xx[rootLength, xx.length]
        matched = false
        conf[:dropbox][:sync].each { |ii|
          if File.fnmatch?(ii, xx, File::FNM_DOTMATCH)
            matched = true
            break
          end
        }
        if matched
          file = client.get_file(xx)
          dest = File.join(destDir, fileDest)
          File.makedirs(File.dirname(dest))
          File.open(dest, 'w') {|f| f.puts file}
        end
      }
    end

    conf[:dropbox][:sync].each { |ii|
      Dir.glob(File.join(destDir, ii)).each { |oo|
        if !File.directory?(oo)
          upName = Pathname.new(oo).relative_path_from(Pathname.new(destDir)).to_s
          upName = File.join("", conf[:dropbox][:root], upName)
          if files.nil? or !files.has_key?(upName)
            File.open(oo) { |f| client.put_file(upName, f, true) }
          end
        end
      }
    }

    dropboxKeys[:files] = Rypple.walkDropbox(client, conf[:dropbox][:root], {})
    Rypple.cleanup(conf, dropboxKeys, path)

    return true
  end
end
