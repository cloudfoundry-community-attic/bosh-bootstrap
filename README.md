# Stark & Wayne's Bosh Bootstrapper

In order to deploy CloudFoundry, and a growing number of other complex systems, you will need a BOSH. BOSH provides a complete lifecycle manager/deployer for complex systems. CloudFoundry is a very complex system when it comes to deployment/upgrades.

The Stark & Wayne Bosh Bootstrapper is the simplest way to get a Micro BOSH running, to upgrade an existing Micro BOSH, and to delete it if you change your mind. 

Bootstrap a Micro BOSH universe from one CLI command. Also allows SSH access and the ability to delete created Micro BOSHes.

```
$ bosh-bootstrap deploy --latest-stemcell
Creating inception VM...
Creating micro BOSH VM...

$ bosh-bootstrap ssh
Open SSH tunnel to inception VM...

$ bosh-bootstrap delete
Deleting micro BOSH VM...
```

It is now very simple to bootstrap a micro BOSH from a single, local CLI. The bootstrapper first creates an inception VM and then uses the `bosh_deployer` (`bosh micro deploy`) to deploy micro BOSH.

To be cute about it, the Stark & Wayne Bosh Bootstrapper aims to provide lifecycle management for the BOSH lifecycle manager. Zing! See the "Deep dive into deploy command" section below for greater understanding why the Stark & Wayne Bosh Bootstrapper is very useful.

## Installation

This bootstrapper for BOSH is distributed as a RubyGem for Ruby 1.8+.

```
$ gem install bosh-bootstrap
```

## Usage

### First time usage

The first time you use `bosh-bootstrap` it will create everything necessary. The example output below includes user prompts.

```
$ bosh-bootstrap deploy --latest-stemcell

Stage 1: Choose infrastructure

Found infrastructure API credentials at ~/.fog (override with --fog)
1. AWS (default)
2. AWS (bosh)
3. Rackspace (default)
Choose infrastructure:  1

Confirming: using AWS infrastructure.

1. ap-northeast-1
2. ap-southeast-1
3. eu-west-1
4. us-east-1
5. us-west-1
6. us-west-2
7. sa-east-1
Choose AWS region:  6
Confirming: Using AWS us-west-2 region.


Stage 2: Configuration

Confirming: Micro BOSH will be named microbosh_aws_us_east_1

BOSH username: drnic
BOSH password: ********
Confirming: After BOSH is created, your username will be drnic

Confirming: Micro BOSH will be assigned IP address 174.129.227.124

Confirming: Micro BOSH protected by security group named microbosh_aws_us_east_1, with ports [22, 6868, 25555, 25888]

Confirming: Micro BOSH accessible via key pair named microbosh_aws_us_east_1

Confirming: Micro BOSH will be created with stemcell micro-bosh-stemcell-aws-0.6.4.tgz


Stage 3: Create/Allocate the Inception VM

1. create new inception VM
2. use an existing Ubuntu server
3. use this server (must be ubuntu & on same network as bosh)
Create or specify an Inception VM:  1

Confirming: Inception VM has been created

Stage 4: Preparing the Inception VM

Successfully created vcap user
Successfully installed base packages
Successfully installed ruby 1.9.3
Successfully installed useful ruby gems
Successfully installed bosh
Successfully captured value of salted password
Successfully validated bosh deployer

Stage 5: Deploying micro BOSH

Successfully downloaded micro-bosh stemcell
Successfully uploaded micro-bosh deployment manifest file
Successfully installed key pair for user
Successfully deploy micro bosh
```

### Local usage

During the `bosh-bootstrap deploy` sequence above, you could choose to use the local VM as the Inception VM. 

For AWS, it is important that you only use a VM that is on the same infrastructure region. The process of creating a micro-bosh VM is to use a local
EBS volume to create an AMI. The target region for the micro-bosh VM must therefore be in the same region.

### Repeat usage

The `deploy` command can be re-run and it will not prompt again for inputs. It aims to be idempotent. This means that if you see any errors when running `deploy`, such as unavailability of VMs or IP addresses, then when you resolve those issues you can re-run the `deploy` command and it will resume the bootstrap of micro-bosh (and the optional inception VM).

## SSH access

You can open an SSH shell with the Inception VM:

```
$ bosh-bootstrap ssh
```

You can also pass a COMMAND argument and that command will be run instead of the shell being opened.

```
$ bosh-bootstrap ssh 'whoami'
ubuntu
```

## Deleting micro BOSH

The `bosh-bootstrap delete`  command will delete the target micro-bosh.

```
$ bosh-bootstrap delete
Stage 1: Target inception VM to use to delete micro-bosh

Confirming: Using inception VM ubuntu@ec2-184-73-231-239.compute-1.amazonaws.com

Stage 2: Deleting micro BOSH
Delete micro BOSH
  stopping agent services (00:00:01)                                            
  unmount disk (00:00:10)                                                       
  detach disk (00:00:13)                                                        
  delete disk (00:02:35)                                                        
  delete VM (00:00:37)                                                          
  delete stemcell (00:00:00)                                                    
Done                          6/6 00:03:37                                      
Deleted deployment 'microbosh-aws-us-east-1', took 00:03:37 to complete
```

## Deep dive into the BOSH Bootstrap deploy command

What is actually happening when you run `bosh-bootstrap deploy`?

At the heart of `bosh-bootstrap deploy` is the execution of the BOSH Deployer, a command provided with BOSH to bootstrap a single VM with all the parts of BOSH running on it. If you ran this command yourself you would run:

```
$ gem install bosh-deployer
$ bosh download public stemcell some-microbosh-stemcell.tgz
$ bosh micro deploy some-microbosh-stemcell.tgz
```

Unfortunately for this simple scenario, there are many little prerequisite steps before those three commands. The Stark & Wayne Bosh Bootstrapper replaces pages and pages of step-by-step instructions with a single command line that does everything. It even allows you to upgrade your Micro BOSH with newer BOSH releases: both publicly available stemcells and custom stemcells generated from the BOSH source code.

To understand exactly what the `bosh-bootstrap deploy` command is doing, let's start with what the running parts of BOSH are and how `bosh micro deploy` deploys them.

### What is in BOSH?

A running BOSH, whether it is running on a single server or a cluster of servers, is a collection of processes. The core of BOSH is the Director and the Blobstore. The remaining processes provide support, storage or messaging.

* The Director, the public API for the bosh CLI and coordinator of BOSH behavior
* The Blobstore, to store and retrieve precompiled packages
* Agents, run on each server within deployments
* The Health Manager, to track the state of deployed systems (the infrastructure and running jobs)
* Internal DNS, called PowerDNS, for internal unique naming of servers within BOSH deployments
* Registry, for example AWS Registry, for tracking the infrastructure that has been provisioned (servers, persistent disks)
* PostgreSQL
* Redis

When you deploy a BOSH using the BOSH Deployer (`bosh micro deploy`) or indirectly via the BOSH Bootstrapper, you are actually deploying a BOSH release that describes a BOSH called [bosh-release](https://github.com/cloudfoundry/bosh-release). The processes listed above are called "jobs" and you can see the full list of jobs inside a BOSH within the [jobs/ directory](https://github.com/cloudfoundry/bosh-release/jobs) of `bosh-release`.

But you don't yet have a BOSH to deploy another BOSH.

### How to get your first BOSH?

The BOSH Deployer (`bosh micro deploy`) exists to spin you up a pre-baked server with all the packages and jobs running.

When you run the BOSH Deployer on a server, it does not convert that server into a BOSH. Rather, it provisions a single brand new server, with all the required packages, configuration and startup scripts. We call this pre-baked server a Micro BOSH.

A Micro BOSH server is a normal running server built from a base OS image that already contains all the packages, configuration and startup scripts for the jobs listed above.

In BOSH terminology, call these pre-packaged base OS images "stemcells".

For AWS, vSphere and OpenStack there are publicly available stemcells that can bootstrap a Micro BOSH for that infrastructure. To see the current list of all public Micro BOSH stemcells for all infrastructure providers; and to download one of them:

```
$ bosh public stemcells --tag micro
$ bosh download public stemcell micro-bosh-stemcell-aws-0.6.4.tgz
```

The CloudFoundry BOSH team will release new public stemcells overtime. The BOSH Deployer allows you to upgrade to newer stemcells as easily as it is to deploy a Micro BOSH initially.

```
$ bosh micro deploy micro-bosh-stemcell-aws-0.6.4.tgz
$ bosh micro deploy micro-stemcell-aws-0.7.0.tgz --update
```

### Configuring a Micro BOSH

The command above will not work without first providing BOSH Deployer with configuration details. The stemcell file alone is not sufficient information. When we deploy or update a Micro BOSH we need to provide the following:

* A static IP address - this IP address will be bound to the initial Micro BOSH server, and when the Micro BOSH is updated in future and the server is thrown away and replaced, then it is bound to the replacement servers
* Server properties - the instance type (such as m1.large on AWS) or RAM/CPU combination (on vSphere)
* Server persistent disk - a single persistent, attached disk volume will be provisioned and mounted at `/var/vcap/store`; when the Micro BOSH is updated is is unmounted, unattached from the current server and then reattached and remounted to the upgraded server
* Infrastructure API credentials - the magic permissions for the Micro BOSH to provision servers and persistent disks for its BOSH deployments

This information is to go into a file called `/path/to/deployments/NAME/micro_bosh.yml`. Before `bosh micro deploy` is run, we first need to tell BOSH Deployer which file contains the Micro BOSH deployment manifest.

In the Stark & Wayne Bosh Bootstrapper, the manifests are stored at `/var/vcap/store/microboshes/deployments/NAME/micro_bosh.yml`.

So the BOSH Deployer command that is run to specify the deployment manifest and run the deployment is:

```
$ bosh micro deployment `/var/vcap/store/microboshes/deployments/NAME/micro_bosh.yml`
$ bosh micro deploy /var/vcap/store/stemcells/micro-bosh-stemcell-aws-0.6.4.tgz
```

### Why does it take so long to deploy Micro BOSH on AWS?

On AWS it can take over 20 minutes to deploy or upgrade a Micro BOSH from a public stemcell. The majority of this time is taken with converting the stemcell file (such as `micro-bosh-stemcell-aws-0.6.4.tgz`) into an Amazon AMI.

When you boot a new server on AWS you provide the base machine image for the root filesystem. This is called the Amazon Machine Image (AMI). For our Micro BOSH, we need an AMI that contains all the packages, process configuration and startup scripts. That is, we need to convert our stemcell into an AMI; then use the AMI to boot the Micro BOSH server.

The BOSH Deployer performs all the hard work to create an AMI. Believe me, it is a lot of hard work.

The summary of the process of creating the Micro BOSH AMI is:

1. Create a new EBS volume (an attached disk) on the server running BOSH Deployer
2. Unpack/upload the stemcell onto the EBS volume
3. Create a snapshot of the EBS volume
4. Register the snapshot as an AMI

This process takes the majority of the time to deploy a new/replacement Micro BOSH server.

### Why can't I run BOSH Deployer from my laptop?

One of the feature of the BOSH Bootstrapper is that you can run it from your local laptop. BOSH Deployer itself cannot be run from your laptop. The reason is hidden in the step-by-step AMI example above. In AWS, to create an EBS volume, create a snapshot and register it as an AMI, you need to be running the commands on an AWS server in the same target region as your future Micro BOSH server.

The server that runs the BOSH Deployer is commonly called the Inception VM. For AWS you need an Inception VM in the same AWS region that you will provision your Micro BOSH server. Since a BOSH also manages a stemcell process similar to the above, your BOSH must be in the same AWS region that you a deploying BOSH releases.

### How does BOSH Bootstrapper get around this requirement?

The BOSH Bootstrapper can run from your laptop or locally from an Inception VM. 

If you run it from your laptop, then it will prompt you to create a new Inception VM or for the host/username of a pre-existing Ubuntu server. The BOSH Bootstrapper will then use SSH to command the Inception VM to perform all the deployment steps discussed above.

That is the core of the service being provided by the BOSH Bootstrapper - to prepare an Inception VM and to command it to deploy and upgrade Micro BOSHes.

## Internal configuration/settings

Once you've used the CLI it stores your settings for your BOSH, so that you can re-run the tool for upgrades or other future functionality.

By default, the settings file is stored at `~/.bosh_bootstrap/manifest.yml`.

For an AWS BOSH it looks like:

``` yaml
---
fog_path: /Users/drnic/.fog
fog_credentials:
  provider: AWS
  aws_access_key_id: ACCESS_KEY
  aws_secret_access_key: SECRET_KEY
  region: us-east-1
bosh_cloud_properties:
  aws:
    access_key_id: ACCESS_KEY
    secret_access_key: SECRET_KEY
    default_key_name: microbosh
    default_security_groups:
    - microbosh
    ec2_private_key: /home/vcap/.ssh/microbosh.pem
bosh_resources_cloud_properties:
  instance_type: m1.medium
bosh_provider: aws
region_code: us-east-1
bosh_username: drnic
bosh_password: PASSWORD
bosh:
  password: PASSWORD
  salted_password: 'sdfkjhadsjkadsfjhdsf'
  persistent_disk: 16384
  ip_address: 107.22.247.45
micro_bosh_stemcell_name: "micro-bosh-stemcell-aws-0.6.4.tgz"
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

All documentation and source code is copyright of Stark & Wayne LLC.

## Subscription and Support

This documentation & tool is freely available to all people and companies coming to CloudFoundry and BOSH.

If you decide to run CloudFoundry and BOSH in production, please purchase a Subscription and Support Agreement with Stark & Wayne so we can continue to create and maintain top quality documentation and tools; and also provide you with bespoke support for your deployments. We want to help you be successfully.

