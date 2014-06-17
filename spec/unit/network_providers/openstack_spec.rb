require "readwritesettings"
require "fakeweb"
require "bosh-bootstrap/network_providers/openstack"

describe Bosh::Bootstrap::NetworkProviders::OpenStack do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:provider_client) { instance_double("Cyoi::Providers::Clients::OpenStackProviderClient") }
  subject { Bosh::Bootstrap::NetworkProviders::OpenStack.new(provider_client) }

  it "is registered" do
    Bosh::Bootstrap::NetworkProviders.provider_class("openstack").should == subject.class
  end

  it "creates security groups it needs" do
    expected_groups = [
      ["ssh", "ssh", 22],
      ["dns_server", "dns_server", { protocol: "udp", ports: (53..53) }],
      ["bosh", "bosh", [4222, 6868, 25250, 25555, 25777]]
    ]
    expected_groups.each do |security_group_name, description, ports|
      expect(provider_client).to receive(:create_security_group).with(security_group_name, description, ports)
    end
    subject.perform
  end
end
