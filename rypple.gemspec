# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "lib/rypple/version"

Gem::Specification.new do |s|
  s.name          = "rypple"
  s.version       = Rypple::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Jason Ziglar"]
  s.email         = ["jasedit@catexia.com"]
  s.homepage      = "https://github.com/jasedit/rypple"
  s.summary       = %q{Dropbox interface for jekyll.}
  s.description   = %q{A gem providing a Dropbox syncing interface for jekyll, along with a cgi file to update jekyll.}

  s.add_runtime_dependency "jekyll"
  s.add_runtime_dependency "dropbox-sdk"
  s.add_runtime_dependency "require_all"

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
