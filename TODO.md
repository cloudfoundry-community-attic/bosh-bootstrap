## Known issues

* Need key pair (delegate to cyoi)
  * microbosh_providers/aws.rb - private_key_path has hardcoded root `/home/vcap/microboshes/`
* setup hard coded settings.bosh.X from options or defaults

## Cyoi

## Validations

If using stemcells, then must be Ubuntu with following packages installed:

* libsqlite3-dev
* genisoimage

How can we validate that there is enough disk space to download & prepare the stemcell?

### AWS

* check if this server is in AWS & same region as target region, else only use AMIs
