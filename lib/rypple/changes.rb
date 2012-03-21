#!/usr/bin/ruby

require 'fileutils'

module Rypple

  class FileChanges
    attr_reader :dest
    attr_reader :src
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
