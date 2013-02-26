# Change Log

`bosh-bootstrap` is a command line tool that you can run on your laptop and automatically get a microbosh (and an inception VM) deployed on either AWS or OpenStack.

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

* AWS VPC support was begin by the core BOSH team; though work has stopped sadly.
* Growing number of specs mostly using Fog.mock! mode; tests being run on travis


## v0.6

Highlights:

* Defaults to downloading latest stemcell (rather than stable, which are getting old now).
* Installs the Cloud Foundry plugin for BOSH https://github.com/StarkAndWayne/bosh-cloudfoundry

Additions:

* `tmux` - if you have tmux installed, then you can SSH into inception VM with it (thx @mrdavidlang)
* started a test suite; its small but growing! (thx @mrdavidlang for getting it started)

Bug fixes:

* Fog::SSH uses explicit ssh key that was requested to access inception VM

Future thoughts:

* I hate Settingslogic for read-write settings. It's really only a read-only settings DSL. It puts Ruby classes into the YAML. Probably going to rip it out.
* I am so sorry I took so long to start writing tests. It always seemed such a hard thing to write tests for. But bosh-cloudfoundry project has had good success with internal tests; so we're migrating those ideas into this project.