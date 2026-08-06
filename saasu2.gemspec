# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'saasu/version'

Gem::Specification.new do |spec|
  spec.name          = "saasu2"
  spec.version       = Saasu::VERSION
  spec.authors       = ["Nick Sinenko"]
  spec.email         = ["nick.sinenko@gmail.com"]

  spec.summary       = %q{Ruby wrapper for Saasu API.}
  spec.homepage      = "https://api.saasu.com"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 1.9.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"

  spec.add_dependency "faraday"
  spec.add_dependency "faraday_middleware"
  spec.add_dependency 'activesupport'
  spec.add_dependency "activemodel", ">= 6.1"
end
