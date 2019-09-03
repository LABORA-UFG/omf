# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "omf_common/version"

Gem::Specification.new do |s|
  s.name        = "omf_common"
  s.version     = OmfCommon::VERSION
  s.authors     = ["NICTA"]
  s.email       = ["omf-user@lists.nicta.com.au"]
  s.homepage    = "http://omf.mytestbed.net"
  s.summary     = %q{Common library of OMF}
  s.description = %q{Common library of OMF, a generic framework for controlling and managing networking testbeds.}
  s.required_ruby_version = '>= 1.9.3'
  s.license = 'MIT'

  s.rubyforge_project = "omf_common"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "minitest", "= 5.8.5"
  s.add_development_dependency "evented-spec", "~> 1.0.0.beta"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "pry"
  s.add_development_dependency "mocha"

  s.add_runtime_dependency "activesupport", "= 5.2.1"
  s.add_runtime_dependency "eventmachine", "= 1.2.7"
  s.add_runtime_dependency "logging", "= 1.8.2"
  s.add_runtime_dependency "hashie", "= 3.4.6"
  s.add_runtime_dependency "oml4r", "= 2.10.6"
  s.add_runtime_dependency "amqp", "= 1.8.0"
  s.add_runtime_dependency "uuidtools"
  s.add_runtime_dependency "sourcify", "= 0.5.0"

  s.add_runtime_dependency "oj", "= 3.3.2"
  s.add_runtime_dependency "oj_mimic_json", "= 1.0.1"
  s.add_runtime_dependency "json-jwt", "= 1.7.2"
  s.add_runtime_dependency "highline"
end
