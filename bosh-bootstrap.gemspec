# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bosh-bootstrap/version'

Gem::Specification.new do |gem|
  gem.name          = "bosh-bootstrap"
  gem.version       = Bosh::Bootstrap::VERSION
  gem.authors       = ["Dr Nic Williams"]
  gem.email         = ["drnicwilliams@gmail.com"]
  gem.description   = %q{Bootstrap a micro BOSH universe from one CLI}
  gem.summary       = <<-EOS
bosh-bootstrap configures and deploys a microbosh deployed on either
AWS or OpenStack.
EOS
  gem.homepage      = "https://github.com/StarkAndWayne/bosh-bootstrap"

  gem.required_ruby_version = '>= 1.9'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "thor"
  gem.add_dependency "highline"
  gem.add_dependency "settingslogic"
  gem.add_dependency "escape"
  gem.add_dependency "redcard"
  gem.add_dependency "bosh_cli", "~> 1.5.0.pre"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "activesupport", ">= 3.0.0"
end
