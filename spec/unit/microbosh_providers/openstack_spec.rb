require "readwritesettings"
require "bosh-bootstrap/microbosh_providers/openstack"

describe Bosh::Bootstrap::MicroboshProviders::OpenStack do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}

  context "creates micro_bosh.yml manifest" do
    it "on nova with floating IP" do
      setting "provider.name", "openstack"
      setting "provider.credentials.openstack_auth_url", "http://10.0.0.2:5000/v2.0/tokens"
      setting "provider.credentials.openstack_username", "USER"
      setting "provider.credentials.openstack_api_key", "PASSWORD"
      setting "provider.credentials.openstack_tenant", "TENANT"
      setting "provider.credentials.openstack_region", "REGION"
      setting "address.ip", "1.2.3.4"
      setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
      setting "bosh.name", "test-bosh"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.persistent_disk", 16384

      subject = Bosh::Bootstrap::MicroboshProviders::OpenStack.new(microbosh_yml, settings)

      subject.create_microbosh_yml(settings)
      File.should be_exists(microbosh_yml)
      yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.nova_vip.yml"))
    end


    it "on neutron with public gateway & floating IP" do
      setting "provider.name", "openstack"
      setting "provider.credentials.openstack_auth_url", "http://10.0.0.2:5000/v2.0/tokens"
      setting "provider.credentials.openstack_username", "USER"
      setting "provider.credentials.openstack_api_key", "PASSWORD"
      setting "provider.credentials.openstack_tenant", "TENANT"
      setting "provider.credentials.openstack_region", "REGION"
      setting "network.subnet_id", "7b8788eb-b49e-4424-9065-75a6b07094ea"
      setting "network.pool_name", "INTERNET"
      setting "address.ip", "1.2.3.4" # network.vip
      setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
      setting "bosh.name", "test-bosh"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.persistent_disk", 16384

      subject = Bosh::Bootstrap::MicroboshProviders::OpenStack.new(microbosh_yml, settings)

      subject.create_microbosh_yml(settings)
      File.should be_exists(microbosh_yml)
      yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.neutron_vip.yml"))
    end

    it "on neutron with internal static IP only" do
      setting "provider.name", "openstack"
      setting "provider.credentials.openstack_auth_url", "http://10.0.0.2:5000/v2.0/tokens"
      setting "provider.credentials.openstack_username", "USER"
      setting "provider.credentials.openstack_api_key", "PASSWORD"
      setting "provider.credentials.openstack_tenant", "TENANT"
      setting "provider.credentials.openstack_region", "REGION"
      setting "network.subnet_id", "7b8788eb-b49e-4424-9065-75a6b07094ea"
      setting "address.ip", "10.10.10.3" # network.ip
      setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
      setting "bosh.name", "test-bosh"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.persistent_disk", 16384

      subject = Bosh::Bootstrap::MicroboshProviders::OpenStack.new(microbosh_yml, settings)

      subject.create_microbosh_yml(settings)
      File.should be_exists(microbosh_yml)
      yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.neutron_manual.yml"))
    end
  end
end