## Known issues

* specify an AZ to use in the region
* target & create user after deployment
* upgrade (if its already running successfully; else delete & redeploy)
* multiple deployments
  * bosh name (currently fixed at test-bosh)
  * ~/.microbosh folder is singular


### Specify region

You run the tool, it fails because of region restrictions.

Add the following to your settings.yml

``` yaml
provider:
  name: "aws"
  ignore_az:
  - us-east-1b
  - us-west-2c
```

Or:

``` yaml
provider:
  name: "aws"
  region: us-east-1
  az: us-east-1c
```

The AZ choice then maps into `micro_bosh.yml`:

``` yaml
resources:
  cloud_properties:
    availability_zone: AZ
```

### Display status

```
$ ~/.microbosh/deployments 
$ bundle exec bosh micro status
Stemcell CID   ami-53137a3a
Stemcell name  ami-53137a3a
VM CID         i-78046912
Disk CID       vol-cebe9196
Micro BOSH CID bm-2b31bf69-b676-4db1-a084-fd1ac49377ac
Deployment     /Users/drnic/.microbosh/deployments/test-bosh/micro_bosh.yml
Target         https://107.21.94.132:25555
```
### Create user

Collect user/password at start of process; then target & create user at the end

```
bosh -u admin -p admin target https://107.21.94.132:25555
bosh -u admin -p admin create user drnic PASSWORD (do not display password)
```

## Multiple deployments

* bosh name (currently fixed at test-bosh)
* ~/.microbosh folder is singular

## Bonus

* AWS/us-east-1 - upload light stemcell
* Others - upload normal base stemcell

## Validations

If using stemcells, then must be Ubuntu with following packages installed:

* libsqlite3-dev
* genisoimage

* IP address - like key pair, check that its still available else create new one

How can we validate that there is enough disk space to download & prepare the stemcell?

### AWS

* check if this server is in AWS & same region as target region, else only use AMIs (and switch to us-east-1)

