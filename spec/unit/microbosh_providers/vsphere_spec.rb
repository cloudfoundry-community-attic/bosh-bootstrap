require "readwritesettings"
require "bosh-bootstrap/microbosh_providers/vsphere"

describe Bosh::Bootstrap::MicroboshProviders::VSphere do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}
  let(:fog_compute) { instance_double("Fog::Compute::VSphere") }

  it "creates micro_bosh.yml manifest" do
    setting "provider.name", "vsphere"
    setting "provider.credentials.vsphere_server", "HOST"
    setting "provider.credentials.vsphere_username", "user"
    setting "provider.credentials.vsphere_password", "TempP@ss"

    setting "provider.resources.persistent_disk", "32768"
    setting "provider.resources.ram", "2048"
    setting "provider.resources.disk", "32768"
    setting "provider.resources.cpu", "2"

    # TODO - perhaps network.ip_address is better?
    setting "address.ip", "172.23.194.100"
    setting "provider.network.name", "VLAN2194"
    setting "provider.network.netmask", "255.255.254.0"
    setting "provider.network.gateway", "172.23.194.1"
    setting "provider.network.dns", %w[172.22.22.153 172.22.22.154]

    setting "provider.ntps", %w[ntp01.las01.emcatmos.com ntp02.las01.emcatmos.com]
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

    subject = Bosh::Bootstrap::MicroboshProviders::VSphere.new(microbosh_yml, settings, fog_compute)

    subject.create_microbosh_yml(settings)
    expect(File).to be_exists(microbosh_yml)
    yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.vsphere.yml"))
  end
end
