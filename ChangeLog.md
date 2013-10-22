# Change Log

`bosh-bootstrap` is a command line tool that you can run on your laptop and automatically get a microbosh (and an inception VM) deployed on AWS (with OpenStack & vSphere coming soon).

    gem install bosh-bootstrap
    bosh-bootstrap deploy

## Next


## v0.11

* Complete rewrite of bosh-bootstrap in orphan branch
* CodeClimate score changed from 0.82 to 3.85
* Initial support for AWS EC2; WIP for OpenStack; initial unit tests for vSphere
* Interactive Q&A is extracted into [cyoi](https://github.com/drnic/cyoi) (choose-your-own-infrastructure) library
* Accessing settings is much cleaner; functionality moved into fork of settingslogic called [readwritesettings](https://github.com/drnic/readwritesettings)
* Inception VM/server is now provisioned via separate CLI project [inception-server](https://github.com/drnic/inception-server)
* AWS/us-east-1 uses public AMIs; other regions & other CPIs use stemcells
* CLI via bosh plugin (`bosh bootstrap`) rather than a stand alone CLI (`bosh-bootstrap`)
* Added `ssh` action to ssh into the microbosh
* Added `delete` actions to delete the microbosh (but not the IP address and security groups)
* Add back `bosh-bootstrap` CLI & remove bosh_cli dependency (v0.11.1)
* Specify which AWS AZ to use via `provider.az` in settings.yml (v0.11.2)
* Support for OpenStack (also in cyoi 0.4.3) thanks to Ferdy! (v0.11.3)
* Ensure CLI loads bundler (v0.11.4)
* rubygem users should be able to install & run from rubygems instead of source workaround (v0.11.5)
* microbosh volume is smaller 4G and automatically fits on devstack/openstack (v0.11.5; thx @ryfow)
* Security group `bosh_agent_http` renamed to `bosh_agent_https`, with same 6868 port for talking to bosh_agent running in https mode (`bosh_agent_http` can then be deleted) (v0.11.5)
* Add port 53/dns security group (v0.11.6)
* Port 53 open on UDP only as workaround for multi-region AWS (v0.11.7; thx @yudai)
* Suppress bundler git "fatal" warnings (by converting ~/.microbosh into git repo) (v0.11.8)
* Update to newer-er-er stemcell paths from Pivotal's s3 bucket (v0.11.9, v0.11.10)
* Enlarge persistent disk from 4G to 16G (v0.11.11)
* bosh_cli gems now on rubygems instead of pivotal s3 bucket (v0.11.12)

## v0.10

Available on branch [v0.10](https://github.com/StarkAndWayne/bosh-bootstrap/tree/v0.10).

Install using:

    gem install bosh-bootstrap -v "~> 0.10.0"

* Only using latest pre-release bosh gems & stemcells/amis - do not upgrade if you want the old 2012 gems
* AWS us-east-1 uses a pre-built AMI for extra speed
* AWS all regions are working (using pre-created stemcell)
* OpenStack is now working (using pre-created stemcell)
* `deploy --create-inception` chooses to create an inception VM
* Using `bosh_cli_plugin_micro` (for `bosh micro`) [was `bosh_deployer`]  (v1.10.1)
* `bosh-cloudfoundry` gem installed with prerelease gems (fix in v0.10.1)
* AWS inception VM gets its attached volume again (v1.10.2)

## v0.9

* v0.8 wasn't working for many people; and neither will v0.9; but its a move in the right direction.
* Moving towards new 1.5.0 version of bosh that hasn't come out yet formally.
* AWS us-east-1 will use a pre-created AMI. It saves about 10-15 minutes!
* AWS other regions will use a pre-created stemcell. I haven't tested this well yet.
* OpenStack support is still broken because you need to create your own stemcells and for that you need a 12.10 inception VM and that work isn't quite done yet.

## v0.8

* SSH keys used to access inception VM are now generated and stored within the `~/.bosh_bootstrap/ssh` folder. This fixes many issues that many people were having (their keys had passphrases, their fog_default keypair was old). It also allows a manifest file to be shared between people as it contains the private key contents, and the private key file will be recreated if it is missing.
* existing inception VMs' manifest.yml will be upgraded automatically and a backup file created (just in case)
* tightening of net-ssh & net-scp gems to ensure the bosh-bootstrap gem can be installed [thx @mmb]
* preinstall net-ssh/net-scp/fog on inception VM before installing `bosh_deployer` to fix in ability to install `bosh_deployer` 1.4.1 due to latest fog 1.10.0 release (v0.8.2)

## v0.7

Notable:

* For existing users: please run "deploy --upgrade-deps" as new inception package (runit) added; and jazor/yaml_command CLIs installed
* Forces use of microbosh stemcell 0.8.1 which work with public gems (latest public stemcell does not work with public gems)

Added:

* `mosh` command - connect to Inception VM on trains over flaky internet connections (use instead of `ssh` or `tmux` command) [thx @mrdavidlang]
* `upgrade-inception` command - to perform an upgrade of the Inception VM without triggering a re-deploy of microbosh.

Changes:

* Inception VM now installs rubygems 2.0.0 & bundler 1.3.0
* Better idempotence for re-deploying microbosh - will delete&deploy after a failure; will deploy after a deletion.
* Downloads ubuntu 10.04 ISO to speed up custom stemcell builds
* Using redcard to ensure ruby 1.9 only
* `manifest.yml` stores the name of the stemcell created from a custom stemcell build; no longer re-creates stemcell each time
* git color is enabled on inception VM

Work in progress:

* AWS VPC support was begin by the core bosh team; though work has stopped sadly.
* Growing number of specs mostly using Fog.mock! mode; tests being run on travis

### v0.7.1

* Make "deploy --private-key" option work [thx @dpw]
* Add hypervisor for OpenStack stemcells [thx @frodenas]
* Don't fail if `settings.fog_credentials.openstack_region` doesn't exist
* Fix README for changed location of bosh-release [thx @scottfrederick]
* No need to show  --latest-stemcell in README tutorial

## v0.6

Highlights:

* Defaults to downloading latest stemcell (rather than stable, which are getting old now).
* Installs the Cloud Foundry plugin for bosh https://github.com/StarkAndWayne/bosh-cloudfoundry

Additions:

* `tmux` - if you have tmux installed, then you can SSH into inception VM with it (thx @mrdavidlang)
* started a test suite; its small but growing! (thx @mrdavidlang for getting it started)

Bug fixes:

* Fog::SSH uses explicit ssh key that was requested to access inception VM

Future thoughts:

* I hate Settingslogic for read-write settings. It's really only a read-only settings DSL. It puts Ruby classes into the YAML. Probably going to rip it out.
* I am so sorry I took so long to start writing tests. It always seemed such a hard thing to write tests for. But bosh-cloudfoundry project has had good success with internal tests; so we're migrating those ideas into this project.