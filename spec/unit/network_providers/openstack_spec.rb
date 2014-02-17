require "readwritesettings"
require "fakeweb"
require "bosh-bootstrap/network_providers/openstack"

describe Bosh::Bootstrap::NetworkProviders::OpenStack do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:provider_client) { stub() }
  subject { Bosh::Bootstrap::NetworkProviders::OpenStack.new(provider_client) }

  it "is registered" do
    Bosh::Bootstrap::NetworkProviders.provider_class("openstack").should == subject.class
  end

  it "creates security groups it needs" do
    expected_groups = [
      ["ssh", "ssh", ports: 22],
      ["dns_server", "dns_server", ports: { protocol: "udp", ports: (53..53) }],
      ["bosh", "bosh", ports: [4222, 6868, 25250, 25555, 25777]]
    ]
    expected_groups.each do |security_group_name, description, ports|
      provider_client.stub(:create_security_group).with(security_group_name, description, ports)
    end
    subject.perform
  end
end
