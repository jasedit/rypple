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

# * Interface which represents the syncing portion of Rypple. These components
# * sync files to/from external sources to the Rypple directory. This is a base
# * class - specific interfaces are subclasses defined through +Sync::register+.
class Sync

  attr_reader :provides_input
  attr_reader :provides_output
  # Attribute indicating if this sync interface downloads files for Rypple
  def input?
    puts @@subclasses.keys
    @provides_input
  end

  # Attribute indicating if this sync interface stores files for Rypple.
  def output?
    @provides_output
  end

  # Test to see if there are changes available to save. Returns true if there
  # are changes available for downloading.
  def changes?
    false
  end

  # Get latest changes from the sync method to download.
  #
  # === Attributes
  # +path+ - Absolute path pointing to the directory Rypple is operating on.
  #
  # === Returns
  # If changes exist, this function should return an array of +Add+, +Remove+,
  # and +Move+ objects, matching the relevant change.
  def changes path
  end

  # Takes a list of new files found in the directory, and saves relevant files.
  def save files
  end

  def to_map
  end

end
