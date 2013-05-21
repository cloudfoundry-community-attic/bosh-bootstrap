require "readwritesettings"
require "bosh-bootstrap/microbosh_providers/openstack"

describe Bosh::Bootstrap::MicroboshProviders::OpenStack do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}

  it "creates micro_bosh.yml manifest" do
    setting "provider.name", "openstack"
    setting "provider.credentials.openstack_auth_url", "http://10.0.0.2:5000/v2.0/tokens"
    setting "provider.credentials.openstack_username", "USER"
    setting "provider.credentials.openstack_api_key", "PASSWORD"
    setting "provider.credentials.openstack_tenant", "TENANT"
    setting "address.ip", "1.2.3.4"
    setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
    setting "bosh.name", "test-bosh"
    setting "bosh.salted_password", "salted_password"
    setting "bosh.persistent_disk", 4096

    subject = Bosh::Bootstrap::MicroboshProviders::OpenStack.new(microbosh_yml, settings)

    subject.create_microbosh_yml(settings)
    File.should be_exists(microbosh_yml)
    yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.yml"))
  end
end
