# Bosh::Bootstrap

Bootstrap a micro BOSH universe from one CLI command.

```
$ bosh-bootstrap deploy
Creating inception VM...
Creating micro BOSH VM...

$ bosh-bootstrap delete
Deleting micro BOSH VM...
```

It is now very simple to bootstrap a micro BOSH from a single, local CLI. The bootstrapper first creates an inception VM and then uses the `bosh_deployer` (`bosh micro deploy`) to deploy micro BOSH.

## Installation

This bootstrapper for BOSH is distributed as a RubyGem for Ruby 1.8+.

```
$ gem install bosh-bootstrap
```

## First time usage

The first time you use `bosh-bootstrap` it will create everything necessary. The example output below includes user prompts.

```
$ bosh-bootstrap deploy

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

## Local usage

Instead of creating a new Inception VM, if you already have an Ubuntu VM on the target infrastructure region network then you can use it with the `--local` flag.

```
$ bosh-bootstrap --local
```

You will still be prompted for infrastructure details (a VM does not necessarily know how to talk to its own infrastructure).

Running this command will install packages, an Ruby via RVM, and the BOSH rubygems on your local VM. It will then use the local VM to create the micro BOSH via BOSH deployer (`bosh micro deploy`).

## Advanced usage



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
