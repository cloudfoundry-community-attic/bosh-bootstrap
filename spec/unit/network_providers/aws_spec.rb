require "readwritesettings"
require "fakeweb"
require "bosh-bootstrap/network_providers"
require "bosh-bootstrap/network_providers/aws"

describe Bosh::Bootstrap::NetworkProviders::AWS do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:cyoi_provider_client) { instance_double("Cyoi::Providers::Clients::AwsProviderClient") }
  subject { Bosh::Bootstrap::NetworkProviders::AWS.new(cyoi_provider_client) }

  it "is registered" do
    expect(Bosh::Bootstrap::NetworkProviders.provider_class("aws")).to eq(subject.class)
  end

  it "creates EC2 security groups it needs" do
    expected_groups = [
      ["ssh", "ssh", ports: 22],
      ["dns-server", "dns-server", ports: { protocol: "udp", ports: (53..53) }],
      ["bosh", "bosh", ports: [4222, 6868, 25250, 25555, 25777]]
    ]
    expected_groups.each do |security_group_name, description, ports|
      expect(cyoi_provider_client).to receive(:create_security_group).with(security_group_name, description, ports, {})
    end
    subject.perform(settings)
  end

  it "creates VPC security groups it needs" do
    setting "address.vpc_id", "vpc-id-1234"
    expected_groups = [
      ["ssh", "ssh", ports: 22],
      ["dns-server", "dns-server", ports: { protocol: "udp", ports: (53..53) }],
      ["bosh", "bosh", ports: [4222, 6868, 25250, 25555, 25777]]
    ]
    expected_groups.each do |security_group_name, description, ports|
      expect(cyoi_provider_client).to receive(:create_security_group).
        with(security_group_name, description, ports, {vpc_id: "vpc-id-1234"})
    end
    subject.perform(settings)
  end

end
