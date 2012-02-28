#$:.unshift File.dirname(__FILE__) #For use/testing without the gem.

# Requires all ruby files in a directory.
#
# path - Relative path from here to the directory.
#
# Returns nothing
def require_all(path)
  glob = File.join(File.dirname(__FILE__), path, '*.rb')
  Dir[glob].each { |f| require f }
end

require 'rubygems'

require 'fileutils'
require 'ftools'
require 'yaml'
require 'pathname'

require_all 'rypple'
