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
    <form action="update.cgi" method="POST">
      <input type="submit" value="Ripple">
    </form>
  </body>
</html>
eos

htaccess = <<'eos'
AuthName "Ripple Updater"
AuthType Basic
AuthUserFile %%AUTH_FILE
Require valid-user
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

rippleDir = File.join(inDir, 'ripple')

if !File.exists?(rippleDir)
  begin
    Dir.mkdir(rippleDir)
  rescue SystemCallError
    "Cannot create ripple directory."
  end
end

File.open(File.join(rippleDir, 'update.html'), 'w', 0644) { |f| f.puts updateHTML }

out = File.join(rippleDir, 'update.cgi')
File.open(out, 'w', 0755) { |f| f.puts baseCGI }

puts "Should I enable basic user authentication for the update script? (Y/n):"

answer = gets.chomp!
if answer.nil? or answer.empty? or answer.downcase! == 'y'
  print "Enter user name for authentication:"
  user = gets.chomp!
  print "Enter password for authentication:"
  chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
  salt = chars[rand(chars.size - 1)] + chars[rand(chars.size - 1)]
  pass = gets.chomp!.crypt(salt)
  authFile = File.join(configBase, '.htpasswd')
  File.open(authFile, 'w') { |f| f.puts "#{user}:#{pass}" }
  htaccess.gsub!(/%%AUTH_FILE/, authFile)
  File.open(File.join(rippleDir, '.htaccess'), 'w') { |f| f.puts htaccess }
end

puts "Attempting first update"

if Ripple.sync(configBase)
  puts `jekyll #{inDir} #{outDir}`
else
  puts "Ripple sync failed."
end
