Deploy bosh-bootstrap on OpenStack (Using DevStack)
===================================================

This tutorial is intended for developers/testers without prior experience with OpenStack. However, it is also useful for OpenStack users as it provides interesting insights into this highly popular project.
It is mainly designed to run bosh-bootstrap with minimum hardware requirements.

[Note: DevStack is only used for development/testing purposes. It is not for suitable for production mode.
However, this tutorial still holds good for production scale OpenStack setup as there is hardly anything you have to do on your own,whatever the underlying IaaS is :) ]

--------------
Prerequisities
--------------

Hardware (Minimum)

4GB RAM (8 GB Preferred), 2 CPU Cores (4 Cores Preferred), 160GB Hard Disk

[Note: The hardware requirements will scale up when you move towards deploying bosh-cloudfoundry (It's not covered in this tutorial)]

Software

1. OS - Ubuntu 12.04 Server
2. VM Image - Ubuntu 10.04 Server
3. IaaS - OpenStack (DevStack in this case)

Preparation
-----------

1. Download devstack

git clone https://github.com/openstack-dev/devstack.git

2. Modify end-points in devstack/files/keystone_data.sh

Change

keystone endpoint-create \
            --region RegionOne \
            --service_id $GLANCE_SERVICE \
            --publicurl "http://$SERVICE_HOST:9292" \
            --adminurl "http://$SERVICE_HOST:9292" \
            --internalurl "http://$SERVICE_HOST:9292"

to

keystone endpoint-create \
            --region RegionOne \
            --service_id $GLANCE_SERVICE \
            --publicurl "http://$SERVICE_HOST:9292/v1.0" \
            --adminurl "http://$SERVICE_HOST:9292/v1.0" \
            --internalurl "http://$SERVICE_HOST:9292/v1.0"

3. DevStack has a 5GB volume limit. However, you can increase it by modifying the following line in devstack/stackrc

VOLUME_BACKING_FILE_SIZE=${VOLUME_BACKING_FILE_SIZE:-5130M}

[Note : This tutorial is based on 5GB volume limit only. But in general, having atleast 10GB volume for
each instance is preferred. Feel free to play with volume limit.]

4. Install devstack

cd devstack & ./stack.sh

Define OpenStack env - OS_USERNAME,OS_PASSWORD,OS_TENANT_NAME,OS_AUTH_URL

5. Download Ubuntu 10.04 server cloud image from http://cloud-images.ubuntu.com

wget http://cloud-images.ubuntu.com/lucid/current/lucid-server-cloudimg-amd64-disk1.img

6. Add image in OpenStack

$ name=Ubuntu_10.04
$ image=lucid-server-cloudimg-amd64-disk1.img
$ glance image-create --name=$name --is-public=true --container-format=bare --disk-format=qcow2 < $image

7. Add flavor [Make sure to add ephemeral disk as shown]

$ nova flavor-create m1.bosh 6 2048 20 2 --ephemeral 20 --rxtx-factor 1 --is-public true

8. Also, install ruby 1.9.3. Use rvm or any other method.

9. Generate keypair

ssh-keygen

10. Set up git

git config --global user.name "Your Name Here"
git config --global user.email "your_email@example.com" 

We are done preparing the IaaS(OpenStack) part. Now lets move up the stack.

------------------------
Play with bosh-bootstrap
------------------------

1. Download from git (Or you can use "gem install bosh-bootstrap")

git clone https://github.com/StarkAndWayne/bosh-bootstrap.git

2. bosh-bootstrap is designed to boot instance with 32GB inception VM and 16GB for BOSH server.
For testing/development purpose, we will scale down the requirements(for devstack) to 3GB and 2GB respectively. Or change as per your requirements

vi bosh-bootstrap/lib/bosh-bootstrap/cli.rb

Change

no_tasks do
      DEFAULT_INCEPTION_VOLUME_SIZE = 32 # Gb

to

no_tasks do
      DEFAULT_INCEPTION_VOLUME_SIZE = 3 # Gb

Also, change

 unless settings[:bosh]
          say "Defaulting to 16Gb persistent disk for BOSH"
          password = settings.bosh_password # FIXME dual use of password?
          settings[:bosh] = {}
          settings[:bosh][:password] = password
          settings[:bosh][:persistent_disk] = 16384
          save_settings!
        end

to

 unless settings[:bosh]
          say "Defaulting to 2Gb persistent disk for BOSH"
          password = settings.bosh_password # FIXME dual use of password?
          settings[:bosh] = {}
          settings[:bosh][:password] = password
          settings[:bosh][:persistent_disk] = 2048
          save_settings!
        end

3. Start bootstrapping
If you downloaded bosh-bootstrap gem, then execute "bosh-bootstrap deploy" directly, otherwise

i) cd bosh-bootstrap
   bundle install

ii) cd bin
   ./bosh-bootstrap deploy

[Answer few questions asked by bosh-bootstrap in the initial stages and then, sit back and relax (hopefully!)]

<-------------------------------------------->
Stage 1: Choose infrastructure
Stage 2: BOSH configuration
Stage 3: Create/Allocate the Inception VM
Stage 4: Preparing the Inception VM
Stage 5: Deploying micro BOSH
Stage 6: Setup bosh
<-------------------------------------------->

Notes:

a. If the process fails in between due to some reason, you can restart the bootstrapping after correcting the error, bootstrapping will continue from the point where it failed instead of from the beginning.
b. If for some reason you want to start the process from the beginning, delete ".bosh-boostrap/manifest.yml" file.
c. In case, the Inception VM fails to connect to internet or bosh-bootstrap is unable to mount volume to the instance, then the most probable reason is due to floating ip.Then
  i) Disassociate floating IP from the OpenStack dashboard.
  ii) Edit ".bosh-bootstrap/manifest.yml" file and change the public IP to fixed IP of the instance.
  iii) Redeploy bosh-bootstrap

4. Finishing bootstrap

  i) If everything goes fine, you can see the list of VMs created by bosh-bootstrap. Also you can ssh into the inception VM by "./bosh-bootstrap ssh". Check BOSH status and so on.
 ii) You can see the list of commands by executing "./bosh-bootstrap help"
iii) In case, you face any issue please raise a ticket. 
