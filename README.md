# Bosh::Bootstrap

Bootstrap a micro BOSH universe from one CLI command.

```
$ bosh-bootstrap
Creating inception VM...
Creating micro BOSH VM...
```

It is now very simple to bootstrap a micro BOSH from a single, local CLI. The bootstrapper first creates an inception VM and then uses `bosh_deployer` (`bosh micro deploy`) to deploy micro BOSH.

## Installation

The bootstrapper is distributed as a RubyGem for Ruby 1.8+.

```
$ gem install bosh-bootstrap
```

## First time usage

The first time you use `bosh-bootstrap` it will create everything necessary. The example output below includes user prompts.

```
$ bosh-bootstrap

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

BOSH username: drnic
BOSH password: ********
Confirming: After BOSH is created, your username will be drnic

Determining latest stable microbosh stemcell... (override: --microbosh-stemcell NAME)
Confirming: micro BOSH stemcell being used is 

Stage 3: Create the Inception VM
This bootstrapper uses a VM within the same target region
to manage the micro BOSH VM.

Provisioning m1.small in us-east-1...
Provisioned: i-123456 (m1.small, us-east-1c)

Provisioning static IP for Inception VM in us-east-1...
Provisioned: 1.2.3.4 (us-east-1)
Provisioning static IP for micro BOSH VM in us-east-1...
Provisioned: 2.3.4.5 (us-east-1)

Assigning 1.2.3.4 to i-123456...
Assigned: 1.2.3.4 to i-123456

Provisioning 16G disk in us-east-1...
Provisioned: v-987654

Assigning v-987654 to i-123456 at /var/vcap/store...
Assigned: v-987654 to i-123456 at /var/vcap/store

Stage 4: Preparing the Inception VM

Installing dependent packages...
Creating folders...
Creating SSH keys for root user...
Storing SSH keys into local manifest...
Installing ruby...
Installing BOSH from rubygems... (override: --source to use bosh from git source)

Confirming: BOSH deployer is installed...
$ bosh help micro
[commands displayed]

Stage 5: Deploying micro BOSH

Downloading stemcell microbosh-aws-0.6.7 into /var/vcap/store/stemcells....

Preparing micro BOSH:
* Static IP: 2.3.4.5     (provisioned above)
* Properties: {'instance_type': 'm1.large'}        
                         (override: --bosh-cloud-properties)
* Attached disk: 16 Gb   (override: --bosh-persistent-disk)

Uploading micro_bosh.yml manifest to /var/vcap/store/deployments/microbosh/aws-us-east-1/micro_bosh.yml...

Deploying micro BOSH...

Setting local BOSH CLI to http://2.3.4.5:25555...
Setting inception VM BOSH CLI to http://2.3.4.5:25555...
Creating BOSH user 'drnic'...
Logging in local BOSH CLI...
Logging in inception VM BOSH CLI...

Status of BOSH:
Updating director data... done

Director
  Name      microbosh-aws-us-east-1
  URL       http://2.3.4.5:25555
  Version   0.5.2 (release:ffed4d4a bosh:21e0b0bc)
  User      drnic
  UUID      bbcc7942-0ddf-4d1a-ab54-XXXXXXXXXX
  CPI       aws
```

## Local usage

Instead of creating a new Inception VM, if you already have an Ubuntu VM on the target infrastructure region network then you can use it with the `--local` flag.

```
$ bosh-bootstrap --local
```

You will still be prompted for infrastructure details (a VM does not necessarily know how to talk to its own infrastructure).

Running this command will install packages, an Ruby via RVM, and the BOSH rubygems on your local VM. It will then use the local VM to create the micro BOSH via BOSH deployer (`bosh micro deploy`).

## Advanced usage



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
