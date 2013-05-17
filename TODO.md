## Known issues

* Fog.mock! always enabled
* Need key pair
* Need to create security groups
* microbosh_providers/aws.rb - private_key_path has hardcoded root `/home/vcap/microboshes/`

## Validations

If using stemcells, then must be Ubuntu with following packages installed:

* libsqlite3-dev
* genisoimage

How can we validate that there is enough disk space to download & prepare the stemcell?

### AWS

* check if this server is in AWS & same region as target region, else only use AMIs
