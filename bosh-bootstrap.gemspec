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
end
