#!/usr/bin/ruby
#  Copyright 2012 Jason Ziglar (jasedit@gmail.com)
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

module Rypple

  class FileChanges
    #Absolute path to this file on disk
    attr_reader :dest
    #Relative path to the file from the sync
    attr_reader :src
    #Contents of the file, if available
    attr_reader :file
    def initialize src
      @src = src
      @dest = nil
      @file = nil
    end

    def apply root
      @dest = File.join(root, @src)
    end

    def build_dest root
      dest = File.join(root, @src)
      File.makedirs(File.dirname(dest))
    end
  end

  class Add < FileChanges
    def initialize(src, file)
      super src
      @file = file
    end

    def apply root
      super root
      build_dest root
      File.open(@dest, 'w') { |f| f.puts @file }
    end
  end

  class Remove < FileChanges
    def apply root
      super root
      if File.exists? @dest
        File.directory?(@dest) ? File.remove_dir(@path) : File.remove(@path)
      end
    end
  end

  class Move < FileChanges
    def initialize(old_name, new_name)
      super new_name
      @src = old_name
    end

    def apply root
      super root
      src_path = File.join(root, @src)
      if File.exists? src_path
        File.makedirs(File.dirname(@dest))
        File.mv(input, output)
      end
    end

    def file
      if !@file
        @file = File.read(@dest)
      end
    end
  end

end
