# Bosh Bootstrap

In order to deploy Cloud Foundry, and a growing number of other complex systems, you will need a bosh. bosh provides a complete lifecycle manager/deployer for complex systems. Cloud Foundry is a very complex system when it comes to deployment/upgrades.

Bosh's primary role is orchestration of servers, their persistent storage and networking. It also includes its own packaging and configuration management systems.

Bosh can run on AWS, modern OpenStack, vSphere 5+ and latest vCloud. New infrastructures are being added regularly.

Bosh Bootstrap is the simplest way to get a micro bosh running and upgrade/destroy it over time. It attempts to auto-detect your infrastructure preferences and asks questions for any information it cannot determine.

Bosh Bootstrap currently supports AWS, with OpenStack and vSphere coming soon. To "support" one of Bosh's cloud providers is merely to know how to generate a `micro_bosh.yml` file for that Bosh CPI; and add the interactive Q & A to the [cyoi](https://github.com/drnic/cyoi) library.

It also performs the task as fast as it is possible. On AWS, if a public AMI has been published for your requested region then it will use that (currently: us-east-1/Virginia).

```
$ bosh-bootstrap deploy
Auto-detected infrastructure API credentials at ~/.fog (override with $FOG)
1. AWS (default)
2. AWS (bosh)
3. AWS (starkandwayne)
4. AWS (pivotaltravis)
5. AWS (swblobstore)
6. Alternate credentials
Choose an auto-detected infrastructure:  3

Using provider AWS


1. *US East (Northern Virginia) Region (us-east-1)
2. US West (Oregon) Region (us-west-2)
3. US West (Northern California) Region (us-west-1)
4. EU (Ireland) Region (eu-west-1)
5. Asia Pacific (Singapore) Region (ap-southeast-1)
6. Asia Pacific (Sydney) Region (ap-southeast-2)
7. Asia Pacific (Tokyo) Region (ap-northeast-1)
8. South America (Sao Paulo) Region (sa-east-1)
Choose AWS region: 1

Confirming: Using AWS/us-east-1
Acquiring a public IP address... 107.21.194.123

Confirming: Using address 107.21.194.123

...

Generating ~/.bosh-bootstrap/universes/aws-us-east-1/micro_bosh.yml...
Deploying micro bosh server...

$ bosh-bootstrap ssh
SSH to micro bosh server...

$ bosh-bootstrap delete
Deleting micro bosh VM...
```

It is now very simple to bootstrap a micro bosh from a single, local CLI. 

To be cute about it, the Bosh Bootstrap aims to provide lifecycle management for the bosh lifecycle manager. Zing! See the "Deep dive into deploy command" section below for greater understanding why the Bosh Bootstrap is very useful.

[![Gem Version](https://badge.fury.io/rb/bosh-bootstrap.png)](http://badge.fury.io/rb/bosh-bootstrap) [![Build Status](https://travis-ci.org/StarkAndWayne/bosh-bootstrap.png?branch=master)](https://travis-ci.org/StarkAndWayne/bosh-bootstrap) [![Code Climate](https://codeclimate.com/github/StarkAndWayne/bosh-bootstrap.png)](https://codeclimate.com/github/StarkAndWayne/bosh-bootstrap)

## Installation

This bootstrap tool is distributed as a RubyGem for Ruby 1.9+.

```
$ ruby -v
ruby 1.9.3p385 ...
$ gem install bosh-bootstrap
```

## Usage

Bosh Bootstrap is available primarily as a standalone CLI `bosh-bootstrap`. If you have the bosh CLI installed, then it is also available as a bosh plugin via `bosh bootstrap`. This readme assumes the former usage.

### First time usage

The first time you use `bosh bootstrap` it will create everything necessary, including a public IP address, security groups, a private key, and the all-important micro bosh that you want. The example output below includes user prompts.

```
$ bosh-bootstrap deploy
Auto-detected infrastructure API credentials at ~/.fog (override with $FOG)
1. AWS (default)
2. AWS (bosh)
3. AWS (starkandwayne)
4. AWS (pivotaltravis)
5. AWS (swblobstore)
6. Alternate credentials
Choose an auto-detected infrastructure:  3

Using provider AWS


1. *US East (Northern Virginia) Region (us-east-1)
2. US West (Oregon) Region (us-west-2)
3. US West (Northern California) Region (us-west-1)
4. EU (Ireland) Region (eu-west-1)
5. Asia Pacific (Singapore) Region (ap-southeast-1)
6. Asia Pacific (Sydney) Region (ap-southeast-2)
7. Asia Pacific (Tokyo) Region (ap-northeast-1)
8. South America (Sao Paulo) Region (sa-east-1)
Choose AWS region: 1

Confirming: Using AWS/us-east-1
Acquiring a public IP address... 107.21.194.123

Confirming: Using address 107.21.194.123
Created security group ssh
 -> opened ports ports TCP 22..22 from IP range 0.0.0.0/0
Created security group bosh_nats_server
 -> opened ports ports TCP 4222..4222 from IP range 0.0.0.0/0
Created security group bosh_agent_https
 -> opened ports ports TCP 6868..6868 from IP range 0.0.0.0/0
Created security group bosh_blobstore
 -> opened ports ports TCP 25250..25250 from IP range 0.0.0.0/0
Created security group bosh_director
 -> opened ports ports TCP 25555..25555 from IP range 0.0.0.0/0
Created security group bosh_registry
 -> opened ports ports TCP 25777..25777 from IP range 0.0.0.0/0
Acquiring a key pair firstbosh... done

Confirming: Using key pair firstbosh
Determining stemcell image/file to use... ami-43f49d2a
bundle install
...

bundle exec bosh micro deployment firstbosh
WARNING! Your target has been changed to `https://firstbosh:25555'!
Deployment set to '/Users/drnic/.microbosh/deployments/firstbosh/micro_bosh.yml'
bundle exec bosh -n micro deploy ami-43f49d2a

Deploy Micro BOSH
  using existing stemcell (00:00:00)                                                                
  creating VM from ami-43f49d2a (00:01:10)                                                          
  waiting for the agent (00:02:34)                                                                  
  create disk (00:00:02)                                                                            
  mount disk (00:00:19)                                                                             
  fetching apply spec (00:00:00)                                                                    
  stopping agent services (00:00:02)                                                                
  applying micro BOSH spec (00:00:16)                                                               
  starting agent services (00:00:00)                                                                
  waiting for the director (00:00:59)                                                               
Done                    11/11 00:05:40                                                              
WARNING! Your target has been changed to `https://107.21.94.132:25555'!
Deployment set to '/Users/drnic/.microbosh/deployments/firstbosh/micro_bosh.yml'
Deployed `firstbosh/micro_bosh.yml' to `https://firstbosh:25555', took 00:05:40 to complete
```

Finally, target and create a user:

```
bosh -u admin -p admin target https://107.21.94.132:25555
bosh -u admin -p admin create user
bosh login
```

### Repeat usage

The `deploy` command can be re-run and it will not prompt again for inputs. It aims to be idempotent. This means that if you see any errors when running `deploy`, such as unavailability of VMs or IP addresses, then when you resolve those issues you can re-run the `deploy` command and it will resume the bootstrap of micro-bosh (and the optional inception VM).

### Restrict AWS availability zones

If you get any errors from AWS about availability zones (AZs) being unavailable to your AWS account, or a specific instance type/flavor is not available to you in your AZ, then you can try specifying an explicit AZ in your `~/.microbosh/settings.yml` file.

Add `provider.az` to specify an AZ within the region you have chosen:

```
provider:
  name: "aws"
  region: us-east-1
  az: us-east-1c
```

## SSH access

You can open an SSH shell to your micro bosh:

```
$ bosh-bootstrap ssh
```

## Deleting micro bosh

The `bosh-bootstrap delete` command will delete the target micro-bosh.

```
$ bosh-bootstrap delete
```

## Deep dive into the Bosh Bootstrap deploy command

What is actually happening when you run `bosh-bootstrap deploy`?

At the heart of `bosh-bootstrap deploy` is the execution of the micro bosh deployer, a bosh plugin provided to bootstrap a single VM with all the parts of bosh running on it. If you ran this command yourself you would run:

```
$ gem install bosh_cli_plugin_micro -s https://s3.amazonaws.com/bosh-jenkins-gems/
$ bosh micro deployment path/to/manifest/folder
$ bosh micro deploy ami-43f49d2a
```

Unfortunately for this simple scenario, there are many little prerequisite steps before those three commands. Bosh Bootstrap replaces pages and pages of step-by-step instructions with a single command line that does everything. It even allows you to upgrade your micro bosh with newer bosh releases:

* public machine images (AMIs on AWS)
* publicly available stemcells
* custom stemcells generated from the bosh repository.

To understand exactly what the `bosh-bootstrap deploy` command is doing, let's start with what the running parts of bosh are and how `bosh micro deploy` deploys them.

### What is in bosh?

A running bosh, whether it is running on a single server or a cluster of servers, is a collection of processes. The core of bosh is the Director and the Blobstore. The remaining processes provide support, storage or messaging.

* The Director, the public API for the bosh CLI and coordinator of bosh behavior
* The Blobstore, to store and retrieve precompiled packages
* Agents, run on each server within deployments
* The Health Manager, to track the state of deployed systems (the infrastructure and running jobs)
* Internal DNS, called PowerDNS, for internal unique naming of servers within bosh deployments
* Registry, for example AWS Registry, for tracking the infrastructure that has been provisioned (servers, persistent disks)
* PostgreSQL
* Redis

When you deploy a bosh using the bosh micro deployer (`bosh micro deploy`) or indirectly via the Bosh Bootstrap, you are actually deploying a bosh release that describes a bosh (see [release](https://github.com/cloudfoundry/bosh/tree/master/release) folder). The processes listed above are called "jobs" and you can see the full list of jobs inside a bosh within the [jobs/ directory](https://github.com/cloudfoundry/bosh/tree/master/release/jobs) of the `bosh` repository.

But you don't yet have a bosh to deploy another bosh.

### How to get your first bosh?

The bosh micro deployer (`bosh micro deploy`) exists to spin you up a pre-baked server with all the packages and jobs running.

When you run the bosh micro deployer on a server, it does not convert that server into a bosh. Rather, it provisions a single brand new server, with all the required packages, configuration and startup scripts. We call this pre-baked server a micro bosh.

A micro bosh server is a normal running server built from a base OS image that already contains all the packages, configuration and startup scripts for the jobs listed above.

In bosh terminology, call these pre-packaged base OS images "stemcells".


### Configuring a micro bosh

The command above will not work without first providing bosh micro deployer with configuration details. The stemcell file alone is not sufficient information. When we deploy or update a micro bosh we need to provide the following:

* A static IP address - this IP address will be bound to the initial micro bosh server, and when the micro bosh is updated in future and the server is thrown away and replaced, then it is bound to the replacement servers
* Server properties - the instance type (such as m1.large on AWS) or RAM/CPU combination (on vSphere)
* Server persistent disk - a single persistent, attached disk volume will be provisioned and mounted at `/var/vcap/store`; when the micro bosh is updated is is unmounted, unattached from the current server and then reattached and remounted to the upgraded server
* Infrastructure API credentials - the magic permissions for the micro bosh to provision servers and persistent disks for its bosh deployments

This information is to go into a file called `/path/to/deployments/NAME/micro_bosh.yml`. Before `bosh micro deploy` is run, we first need to tell bosh micro deployer which file contains the micro bosh deployment manifest.

In the Bosh Bootstrap, the manifests are stored at `~/.microbosh/deployments/NAME/micro_bosh.yml`.

So the bosh micro deployer command that is run to specify the deployment manifest and run the deployment is:

```
$ bosh micro deployment `~/.microbosh/deployments/NAME/micro_bosh.yml`
$ bosh micro deploy ami-43f49d2a
```

### Why does it take so long to deploy micro bosh on AWS?

On AWS it can take over 20 minutes to deploy or upgrade a micro bosh from a public stemcell. The majority of this time is taken with converting the stemcell file (such as `micro-bosh-stemcell-aws-0.6.4.tgz`) into an Amazon AMI.

If you are using AWS us-east-1, like the examples above, then you will be automatically given the public AMI. This saves you about 15 minutes. POW!

When you boot a new server on AWS you provide the base machine image for the root filesystem. This is called the Amazon Machine Image (AMI). For our micro bosh, we need an AMI that contains all the packages, process configuration and startup scripts. That is, we need to convert our stemcell into an AMI; then use the AMI to boot the micro bosh server.

The bosh micro deployer performs all the hard work to create an AMI. Believe me, it is a lot of hard work.

The summary of the process of creating the micro bosh AMI is:

1. Create a new EBS volume (an attached disk) on the server running bosh micro deployer
2. Unpack/upload the stemcell onto the EBS volume
3. Create a snapshot of the EBS volume
4. Register the snapshot as an AMI

This process takes the majority of the time to deploy a new/replacement micro bosh server.

### When I run Bosh Bootstrap from my laptop?

One of the feature of the Bosh Bootstrap is that you can run it from your local laptop if you:

* Use AWS region us-east-1 (where there is a public AMI available)
* Use OpenStack or vSphere

### When do I need an inception server?

There are occasions when it is preferable or required to provision a initial server (called an [inception server](https://github.com/drnic/inception-server)) and to run Bosh Bootstrap (`bosh-bootstrap deploy`) within that.

* Using a AWS region other than us-east-1 (you need to be in that region to create an AMI)
* You want much faster internet between your terminal (an ssh session into your inception server) and your micro bosh and deployed servers

To provision an [inception server](https://github.com/drnic/inception-server):

```
$ gem install inception-server
$ inception deploy
$ inception ssh
> gem install bosh-bootstrap
```

Like Bosh Bootstrap, it will prompt for the infrastructure/cloud provider that you want, your credentials and then do everything for you automatically.

## Internal configuration/settings

Once you've used the CLI it stores your settings for your bosh, so that you can re-run the tool for upgrades or other future functionality.

By default, the settings file is stored at `~/.microbosh/settings.yml`.

For an AWS bosh it looks like:

``` yaml
--- 
bosh: 
  name: firstbosh
provider: 
  name: aws
  credentials: 
    provider: AWS
    aws_access_key_id: ACCESS
    aws_secret_access_key: SECRET
  region: us-east-1
address: 
  ip: 107.21.194.123
key_pair: 
  name: firstbosh
  fingerprint: 3c:09:26:84:df:43:92:d7:bb:31:05:e2:77:84:58:c7:d0:aa:27:18
  private_key: |-
    -----BEGIN RSA PRIVATE KEY-----
    42mrej3mV7BzyEzuwYfancQo6cVKUcjWmZPbTU882l8JAoGASGhmtSr/bIZ+sLeQCfdEz0g5xNvF
    ls1q9vuRLx6cJlO0lZgIUhMWU6Ewk5Qt4bbH2vbxiFPEyEAKq52u24aXSBj7HRc8TTyZtbKMuJGM
    l32aFX8NKv2qrErfjI5j43pJ62Hqk6v6F0OYUVQSXRXe2UNavuFt8WR1Adqy8QLW248=
    ...
    -----END RSA PRIVATE KEY-----
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Troubleshooting

### Ruby Version / Psych errors
A bug exists within Bosh requiring Ruby 1.9.3-p327.  See:  https://github.com/cloudfoundry/bosh/issues/112.  This bug will manifest itself with the following error:

```
Incorrect YAML structure in `/var/vcap/store/repos/bosh/release/config/final.yml':
undefined method `root' for #<Psych::Nodes::Mapping:0x00000002e63f50>
```

Upgrading to a more recent version of Ruby will resolve this error.


### Self Signed SSL Certificates
If your test OpenStack implementation is using a self signed SSL certificate, Excon will error out using default SSL verification settings.
Use the following ssl_verify_peer configuration element to silence the errors for Excon.

```yaml
---
provider:
  name: openstack
  credentials:
    connection_options:
      ssl_verify_peer: false
```

Alternatively, for a more secure / production environment, you can use the following configurations:

```yaml
---
provider:
  name: openstack
  credentials:
    connection_options:
		  ssl_ca_path: ENV['SSL_CERT_DIR']
	  	ssl_ca_file: ENV['SSL_CERT_FILE']
```

## Copyright

All documentation and source code is copyright of Stark & Wayne LLC.

## Subscription and Support

This documentation & tool is freely available to all people and companies coming to Cloud Foundry and bosh.
