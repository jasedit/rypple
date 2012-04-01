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

require 'rypple/changes'
require 'rypple/syncs/sync'
require 'dropbox_sdk'

require 'set'

class DropboxSync < Sync
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
      rev = if @dirs[path]
             then @dirs[path]["rev"]
             else nil end
      new_states = @client.metadata(path, 10000, true, rev)
    rescue DropboxNotModified
      puts "#{path} has not changed."
      return nil
    end

    #True if state represents a folder with contents
    if new_states["is_dir"] and new_states.has_key?("contents")
      @dirs[new_states["path"]] = new_states
      new_states["contents"].each{ |xx|
        if xx["is_dir"]
          walk_dropbox(xx["path"])
        else
          @files[xx["path"]] = xx["rev"]
        end
      }
    else
      @files[new_states['path']] = new_states["rev"]
    end
  end

  def load path
    session_conf = YAML::load(File.read(@session_path))

    @session = if session_conf[:session]
        then DropboxSession.deserialize(session_conf[:session])
        else nil
        end

    @access_type = session_conf[:access_type] || :app_folder
    @dirs = session_conf[:dirs] || Hash.new
  end

  def initialize path, config
    @provides_input = true
    @provides_output = true
    #Read config values
    @root = config[:root] || '/'
    @sync = config[:sync] || ["**/*"]
    @session_file = config[:session_file] || ".dropbox.yml"
 
    @session_path = File.join(path, @session_file)
    @path = path
    @dirs = Hash.new
    @files = Hash.new
    @changes = Array.new

    if File.exists?(@session_path)
      load(@session_path)
    end

    if !@session
      build_session
    end

    @client = DropboxClient.new(@session, @access_type)
  end

  def changes?
    walk_dropbox @root
    !@files.empty?
  end

  def changes
    matches = Hash.new
    files_left = @files.keys.to_set
    @sync.each do |xx|
      new_matches = Array.new
      files_left.each do |ii|
        if File.fnmatch?(xx, ii, File::FNM_DOTMATCH)
          matches[ii] = @files[ii]
          new_matches << ii
        end
      end
      files_left = files_left - new_matches.to_set
    end

    matches.each do |key, value|
      file = @client.get_file(key, value)
      offset = Pathname.new(key).relative_path_from(Pathname.new(@root)).to_s
      @changes << Rypple::Add.new(offset, file)
    end

    @changes
  end

  def save files
    save_session
    file_set = files.to_set
    change_set = @changes.to_set

    new_files = file_set - change_set

    new_files.each do |ff|
      src_path = File.join(@root, ff.src)
      case ff.class.to_s
      when 'Add'
        @client.put_file(src_path, ff.file, false, @files[src_path])
      when 'Move'
        @client.file_move(src_path, ff.dest)
      when 'Remove'
        @client.file_delete(ff.dest)
      end
    end
  end

  def save_session
    keys = {
      :session => @session.serialize,
      :access_type => @access_type,
      :dirs => @dirs
    }

    File.open(@session_path, 'w') { |f| f.puts keys.to_yaml }
  end

  def build_changes
  end

  def to_map
    conf = {
      :name => self.class.to_s,
      :root => @root,
      :sync => @sync,
      :session_file => @session_file
    }
  end
end
