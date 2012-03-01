require 'rubygems'
require 'rypple'

module Rypple

  DefaultCGI = <<'eos'
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
require 'rypple'
require 'jekyll'

cgi = CGI.new

puts cgi.header

puts "<h1>Rippling . . .</h1>"
if Rypple.sync(configPath)
  puts "<h1>Generating Static Site</h1>"
  puts `%%COMMAND #{inDir} #{outDir}`
end
eos

  DefaultUpdateForm = <<'eos'
<html>
  <head>
    <title>Rypple</title>
  </head>
  <body>
    <h1> Throw a stone into a pond..</h1>
    <form action="update.cgi" method="POST">
      <input type="submit" value="Rypple">
    </form>
  </body>
</html>
eos

  DefaultHTAccess = <<'eos'
AuthName "Rypple Updater"
AuthType Basic
AuthUserFile %%AUTH_FILE
Require valid-user
eos

# Returns false if installation fails
def Rypple.Setup()
  puts "Configuring the Rypple update script for web use."
  if File.exists?(ENV["HOME"])
    configBase = File.join(ENV["HOME"], 'ryppleSite')
    puts "Please enter directory for Rypple Site. Default:", configBase
  else
    puts "Please enter directory for the new Rypple site."
  end
  directory = gets.chomp!
 
  if !directory.empty?
    configBase = File.expand_path(configBase)
  end

  if !File.exists?(configBase)
    begin
      Dir.mkdir(configBase)
    rescue SystemCallError
      puts "Cannot create directory", configBase, "aborting."
      return false
    end
  end

  conf = Rypple.loadConfiguration(configBase)
  conf[:destinationDir] = directory
  session, client, keys = Rypple.connectToDropbox(configBase)
  
  if !conf.nil? and !keys.nil?
    Rypple.cleanup(conf, keys, configBase)
  end
 
  baseCGI = DefaultCGI.dup 
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
  
  baseCGI.gsub!(/%%IN_DIR/, configBase)
  
  outDir = ""
  while outDir.empty? or !File.exists?(outDir) do
    puts "Where should the static site generator output files?"
    outDir = gets.chomp!

    if !outDir.empty?
      outDir = File.expand_path(outDir)
    else
      puts "Cannot use empty output directory, aborting."
      return false
    end
  
    if !File.exists?(outDir)
      begin
        Dir.mkdir(outDir)
      rescue SystemCallError
        puts "Cannot create output directory", outDir
        next
      end
    end
  end

  baseCGI.gsub!(/%%OUT_DIR/, outDir)
  
  command = File.join("#{ENV["GEM_HOME"]}", 'bin', 'jekyll')
  if File.exists?(command)
    puts "Please enter any arguments to pass to jekyll"
    args = gets.chomp!
    baseCGI.gsub!(/%%COMMAND/, command + ' ' + args)
  end
  
  ryppleDir = File.join(configBase, 'rypple')
  
  if !File.exists?(ryppleDir)
    begin
      Dir.mkdir(ryppleDir)
    rescue SystemCallError
      "Cannot create rypple directory."
    end
  end
  
  File.open(File.join(ryppleDir, 'update.html'), 'w', 0644) { |f| f.puts DefaultUpdateForm }
  
  out = File.join(ryppleDir, 'update.cgi')
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
    htaccess = DefaultHTAccess.gsub(/%%AUTH_FILE/, authFile)
    File.open(File.join(ryppleDir, '.htaccess'), 'w') { |f| f.puts htaccess }
  end

  puts "Attempting first update"
  
  if Rypple.sync(configBase)
    puts `jekyll #{configBase} #{outDir}`
  else
    puts "Rypple sync failed."
  end

  return true
end

end
