#!/bin/ruby
require 'rubygems'
require 'ripple'

baseCGI = <<'eos'
#!/usr/bin/ruby
gemPath = "%%GEM_PATH"
configPath = "%%CONFIG_PATH"
inDir = "%%IN_DIR"
outDir = "%%OUT_DIR"

if !gemPath.empty?
  $:.push(gemPath)
  ENV['GEM_PATH'] = gemPath
end

require 'cgi'
require 'rubygems'
require 'ripple'
require 'jekyll'

cgi = CGI.new

puts cgi.header

puts "<h1>Rippling . . .</h1>"
if Ripple.sync(configPath)
  puts "<h1>Generating Static Site</h1>"
  puts `%%COMMAND #{inDir} #{outDir}`
end
eos

updateHTML = <<'eos'
<html>
  <head>
    <title>Update Site with Ripple!</title>
  </head>
  <body>
    <h1> Throw a stone into the pond..</h1>
    <form action="cgi-bin/update.cgi" method="POST">
      <input type="submit" value="Ripple">
    </form>
  </body>
</html>
eos

configBase = File.join(ENV["HOME"], '.ripple')
puts "Configuring the Ripple update script for web use."
puts "Please enter directory for Ripple Configuration. Default:", configBase
directory = gets.chomp!

if !directory.empty?
  configBase = directory
end

conf = Ripple.loadConfiguration(configBase)
session, client, keys = Ripple.connectToDropbox(configBase)

if !conf.nil? and !keys.nil?
  Ripple.cleanup(conf, keys, configBase)
end

baseCGI.gsub!(/%%CONFIG_PATH/, configBase)

choice = false
insert = true
while !choice do
  puts "Is your web host set up to use ruby gems? (y/N)"
  answer = gets.chomp!.downcase!
  if answer.nil? or answer.empty?
    choice = true
  elsif answer == "n" or answer == "y"
    insert = (answer == "n")
    choice = true
  end
end

if insert
  gemPath = ''
  if ENV.has_key?('GEM_HOME')
    gemPath = ENV['GEM_HOME']  
  else
    puts "Please enter search path for the ruby gems."
    gemPath = gets.chomp!
  end

  baseCGI.gsub!(/%%GEM_PATH/, gemPath)
end

puts "Where should static site files be store?"
inDir = File.expand_path(gets.chomp!)

if !File.exists?(inDir)
  begin
    Dir.mkdir(inDir)
  rescue SystemCallError
    puts "Cannot create", inDir, ", create this directory and run this script again."
    exit
  end
end

baseCGI.gsub!(/%%IN_DIR/, inDir)

puts "Where should the static site generator output files?"
outDir = File.expand_path(gets.chomp!)

if !File.exists?(inDir)
  begin
    Dir.mkdir(outDir)
  rescue SystemCallError
    puts "Cannot create output directory", outDir, ", fix this and run this script again."
    exit
  end
end

baseCGI.gsub!(/%%OUT_DIR/, outDir)

command = File.join("#{ENV["GEM_HOME"]}", 'bin', 'jekyll')
if File.exists?(command)
  puts "Please enter any arguments to pass to jekyll"
  args = gets.chomp!
  baseCGI.gsub!(/%%COMMAND/, command + ' ' + args)
end

installDir = File.join(inDir, 'cgi-bin')
if !File.exists?(installDir)
  begin
    Dir.mkdir(installDir)
  rescue SystemCallError
    puts "Cannot create installation directory", installDir
    exit
  end
end

out = File.join(installDir, 'update.cgi')
File.open(out, 'w', 0755) { |f| f.puts baseCGI }
File.open(File.join(inDir, 'update.html'), 'w', 0644) { |f| f.puts updateHTML }

puts "Attempting first update"

if Ripple.sync(configBase)
  puts `jekyll #{inDir} #{outDir}`
else
  puts "Ripple sync failed."
end
