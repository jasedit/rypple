require 'source.rb'

Sync::register('Dropbox') do

  # Gets the login information for connecting to Dropbox, and configures the
  # sync to have a valid DropboxSession.
  def build_session
    puts "A Dropbox API key/secret is required for accessing your sync files."
    puts "You can visit https://www.dropbox.com/developers/apps to generate these."
    print "Please enter your Dropbox API key:"
    key = gets.chomp
    print "Please enter your Dropbox API secret:"
    secret = gets.chomp
    print "Should this API access be used in sandbox mode? (Y/n):"
    answer = gets.downcase.chomp
    @access_type = (answer == 'n') ? :app_folder : :dropbox

    @session = DropboxSession.new(key, secret)
    @session.get_request_token
    authorize_url = @session.get_authorize_url
    puts "Visit #{authorize_url} to log in to Dropbox. Hit enter when you have done this."
    gets
    @session.get_access_token
  end

  # Iterates over dropbox directory, building a list of paths and files that
  # have updated.
  def walk_dropbox path
    #Here we need to actually sync newest files.
    begin
      new_states = @client.metadata(path, 10000, true, @file_state[path])
    rescue DropboxNotModified
      puts "Files have not changed."
      return nil
    end

    #True if state represents a folder with contents
    if new_states["is_dir"] and new_states.has_key?("contents")
      @dirs[new_states["path"]] = new_states
      new_states["contents"].each{ |xx|
        if xx["is_dir"]
          walkDropbox(xx["path"])
        else
          @files[xx["path"]] = xx["hash"]
        end
      }
    else
      @files[new_states['path']] = new_states["hash"]
    end
  end

  def load path
    session_conf = YAML::load(File.read(@session_path))

    @session = session_conf[:session] ?
      DropboxSession.deserialize(session_conf[:session]) || nil

    @access_type = session_conf[:access_type] || :app_folder
    @state = session_conf[:state] || nil
    @dirs = session_conf[:dirs] || Hash.new
  end

  def initialize path, config
    #Read config values
    @root = config[:root] || '/'
    @sync = config[:sync] || ["**/*"]
    @session_file = config[:session_file] || ".dropbox.yml"
  
    @session_path = File.join(path, @session_file)
    @path = path
    @dirs = Hash.new
    @files = Hash.new

    if File.exists?(@session_path)
      load(@session_path)
    end

    if !@session
      build_session
    end

    @client = DropboxClient.new(@session, @access_type)
  end

  def input?
    true
  end

  def output?
    true
  end

  def changes?
    walk_dropbox @root
    return @files.empty?
  end

  def changes
    @files.each do |key, value|
      puts "File updated #{key}"
    end
  end

  def save files
    save_session
  end

  def save_session
    keys = {
      :session => @session.serialize,
      :access_type => @access_type,
      :state => @state
    }

    File.open(@session_path, 'w') { |f| f.puts keys.to_yaml }
  end
  def build_changes
  end

  def to_map
    conf = {
      :root => @root,
      :sync => @sync,
      :session_file => @session_file
    }
  end
end
