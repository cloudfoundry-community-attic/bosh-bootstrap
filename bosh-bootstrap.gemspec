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
Now very simple to bootstrap a micro BOSH from a single, local CLI.
The bootstrapper first creates an inception VM and then uses
bosh_deployer (bosh micro deploy) to deploy micro BOSH from
an available stemcell.
EOS
  gem.homepage      = "https://github.com/StarkAndWayne/bosh-bootstrap"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
  gem.add_dependency "thor"
  gem.add_dependency "highline"
  gem.add_dependency "settingslogic"
  gem.add_dependency "POpen4"
  gem.add_dependency "win32-open3-19" if ( RUBY_PLATFORM =~ /mswin32/i || RUBY_PLATFORM =~ /mingw32/i )
  gem.add_dependency "net-scp"
  gem.add_dependency "fog", "~>1.8.0"
  gem.add_dependency "escape"
  gem.add_dependency "bosh_cli"
  gem.add_development_dependency "bosh_deployer"
end
