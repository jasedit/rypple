#!/usr/bin/ruby

require 'fileutils'

module Rypple

  class FileChanges
    attr_reader :path
    def initialize rel_path
      @rel_path = rel_path
      @path = nil
    end

    def apply root
      @path = File.join(root, @rel_path)
    end

    def build_path root
      dest = File.join(root, @rel_path)
      File.makedirs(File.dirname(dest))
    end
  end

class Add < FileChanges
  def initialize(rel_path, file)
    super rel_path
    @file = file
  end

  def apply root
    super root
    build_path root
    File.open(@path, 'w') { |f| f.puts @file }
  end
end

class Remove < FileChanges
  def apply root
    super root
    if File.exists? @path
      File.directory?(@path) ? File.remove_dir(@path) : File.remove(@path)
    end
  end
end

class Move < FileChanges
  def initialize(old_name, new_name)
    super old_name
    @dest = new_name
  end

  def apply root
    super root
    if File.exists? @path
      output = File.join(root, @dest)
      File.makedirs(File.dirname(output))
      File.mv(input, output)
    end
  end
end

end
