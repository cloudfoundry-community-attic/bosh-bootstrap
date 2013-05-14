require "settingslogic"

describe Bosh::Bootstrap::Microbosh do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:path_or_ami) { "/path/to/stemcell.tgz" }
  let(:base_path) { File.expand_path("~/.microbosh") }
  let(:settings_dir) { base_path }
  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}
  subject { Bosh::Bootstrap::Microbosh.new(base_path, path_or_ami) }

  describe "aws" do
    before do
      setting "provider.name", "aws"
      setting "provider.region", "us-west-2"
      setting "provider.credentials.aws_access_key_id", "ACCESS"
      setting "provider.credentials.aws_secret_access_key", "SECRET"
      setting "bosh.name", "test-bosh"
      setting "bosh.password", "password"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.public_ip", "1.2.3.4"
      setting "bosh.persistent_disk", 16384
      subject.stub(:sh).with("bundle install")
      subject.stub(:sh).with("bundle exec bosh micro deploy #{path_or_ami}")
    end

    it "deploys new microbosh" do
      subject.deploy("aws", settings)
      File.should be_exists(microbosh_yml)
      files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.aws_ec2.yml"))
    end
  end

  describe "openstack" do
    before do
      setting "provider.name", "openstack"
      setting "provider.credentials.openstack_auth_url", "http://10.0.0.2:5000/v2.0/tokens"
      setting "provider.credentials.openstack_username", "USER"
      setting "provider.credentials.openstack_api_key", "PASSWORD"
      setting "provider.credentials.openstack_tenant", "TENANT"
      setting "bosh.name", "test-bosh"
      setting "bosh.password", "password"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.public_ip", "1.2.3.4"
      setting "bosh.persistent_disk", 4096
      subject.stub(:sh).with("bundle install")
      subject.stub(:sh).with("bundle exec bosh micro deploy #{path_or_ami}")
    end

    it "deploys new microbosh" do
      subject.deploy("openstack", settings)
      File.should be_exists(microbosh_yml)
      files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.yml"))
    end
  end

  describe "vsphere" do
    before do
      # the meaning of each field can be learned from http://www.brianmmcclain.com/using-bosh-with-vsphere-part-1/
      setting "provider.name", "vsphere"
      setting "provider.credentials.host", "HOST"
      setting "provider.credentials.user", "user"
      setting "provider.credentials.password", "TempP@ss"

      setting "provider.network.name", "VLAN2194"
      setting "provider.network.ip", "172.23.194.100"
      setting "provider.network.netmask", "255.255.254.0"
      setting "provider.network.gateway", "172.23.194.1"
      setting "provider.network.dns", %w[172.22.22.153 172.22.22.154]

      setting "provider.npt", %w[ntp01.las01.emcatmos.com ntp02.las01.emcatmos.com]
      setting "provider.datacenter.name", "LAS01"
      setting "provider.datacenter.vm_folder", "BOSH_VMs"
      setting "provider.datacenter.template_folder", "BOSH_Templates"
      setting "provider.datacenter.disk_path", "BOSH_Deployer"
      setting "provider.datacenter.datastore_pattern", "las01-.*"
      setting "provider.datacenter.persistent_datastore_pattern", "las01-.*"
      setting "provider.datacenter.allow_mixed_datastores", true
      setting "provider.datacenter.clusters", ["CLUSTER01"]

      setting "bosh.name", "test-bosh"
      setting "bosh.password", "password"
      setting "bosh.salted_password", "salted_password"
      subject.stub(:sh).with("bundle install")
      subject.stub(:sh).with("bundle exec bosh micro deploy #{path_or_ami}")
    end

    it "deploys new microbosh" do
      subject.deploy("vsphere", settings)
      File.should be_exists(microbosh_yml)
      files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.vsphere.yml"))
    end
  end
  xit "updates existing microbosh" do
    subject.deploy
  end
  xit "re-deploys failed microbosh deployment" do
    subject.deploy
  end
end