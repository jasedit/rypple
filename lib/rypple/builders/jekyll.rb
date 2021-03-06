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

require 'rypple/builder'
require 'jekyll'

class JekyllBuilder
  include Builder

  def initialize config
    @output = config.has_key?(:web_dir) ? config[:web_dir] : nil
  end

  def to_map
    config = {:web_dir => @output}
  end

  def process_directory dir
    dir = File.expand_path(dir)
    out_dir = File.expand_path(@output)
    if File.exists?(dir) && File.exists?(out_dir)
      `jekyll #{dir} #{out_dir}`
    end
  end
end
