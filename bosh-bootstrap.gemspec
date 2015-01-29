# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bosh-bootstrap/version'

Gem::Specification.new do |gem|
  gem.name          = "bosh-bootstrap"
  gem.version       = Bosh::Bootstrap::VERSION
  gem.authors       = ["Dr Nic Williams"]
  gem.email         = ["drnicwilliams@gmail.com"]
  gem.description   = %q{Bootstrap a micro bosh universe from one CLI}
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

  gem.add_dependency "bosh_cli_plugin_micro"
  gem.add_dependency "cyoi", "~> 0.11.3"
  gem.add_dependency "fog", "~> 1.11"
  gem.add_dependency "readwritesettings", "~> 3.0"
  gem.add_dependency "thor", "~> 0.18"
  gem.add_dependency "httpclient", '=2.4.0'

  gem.add_dependency "redcard"
  gem.add_dependency "rbvmomi"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "fakeweb"
end
