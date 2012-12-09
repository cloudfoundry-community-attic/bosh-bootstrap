# Bosh::Bootstrap

Bootstrap a Micro BOSH universe from one CLI command. Also allows SSH access and the ability to delete created Micro BOSHes.

```
$ bosh-bootstrap deploy
Creating inception VM...
Creating micro BOSH VM...

$ bosh-bootstrap ssh
Open SSH tunnel to inception VM...

$ bosh-bootstrap delete
Deleting micro BOSH VM...
```

It is now very simple to bootstrap a micro BOSH from a single, local CLI. The bootstrapper first creates an inception VM and then uses the `bosh_deployer` (`bosh micro deploy`) to deploy micro BOSH.

## Installation

This bootstrapper for BOSH is distributed as a RubyGem for Ruby 1.8+.

```
$ gem install bosh-bootstrap
```

## Usage

### First time usage

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

### Local usage

During the `bosh-bootstrap deploy` sequence above, you could choose to use the local VM as the Inception VM. 

For AWS, it is important that you only use a VM that is on the same infrastructure region. The process of creating a micro-bosh VM is to use a local
EBS volume to create an AMI. The target region for the micro-bosh VM must therefore be in the same region.

### Repeat usage

The `deploy` command can be re-run and it will not prompt again for inputs. It aims to be idempotent. This means that if you see any errors when running `deploy`, such as unavailability of VMs or IP addresses, then when you resolve those issues you can re-run the `deploy` command and it will resume the bootstrap of micro-bosh (and the optional inception VM).

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
