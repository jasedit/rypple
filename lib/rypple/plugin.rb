#!/usr/bin/ruby
# * Mixin which provides the ability for a class to act as a plugin capable base
# * class. In order to enable this functionality, simply include this Module in
# * the base class to make as a plugin.
module Plugin
  @@subclasses = Hash.new

  # Register a new subclass of the class this module is included in, for later
  # creation via the create call. This allows for a plugin-like functionality.
  #
  # ==== Attributes
  # * +:name+ Name of the subclass that will be used to reference it.
  def register name, &block
    if name.empty?
      raise "Cannot create a subclass with an empty name."
    end

    c = Class.new(self, &block)
    c.class_eval("def self.plugin_name() \"#{name}\" end")

    Object.const_set("#{name.to_s.capitalize}#{self.to_s}", c)
    @@subclasses[name] = c
  end

  # The construction method to get a desired subclass based on the string
  # denoting it. This passes whatever arguments beyond the name along to the
  # initialize function.
  def create name, *args
    c = @@subclasses[name]

    if c
      return c.new *args
    else
      raise "#{name} is not a valid subclass of #{c.superclass}"
    end
  end
end
