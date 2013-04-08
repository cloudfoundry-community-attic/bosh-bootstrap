require File.expand_path("../../../spec_helper", __FILE__)
require File.expand_path("../aws_helpers", __FILE__)

require "active_support/core_ext/hash/keys"

describe "AWS deployment using very latest prebuilt gems and AMIs (us-east-1 only)" do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter
  include AwsHelpers

  attr_reader :bosh_name

  before { prepare_aws("edge-prebuilt", aws_region) }
  # after { destroy_test_constructs(bosh_name) unless keep_after_test? }

  # Jenkins AMIs are produced for us-east-1
  def aws_region
    "us-east-1"
  end

  it "creates an EC2 inception/microbosh with the associated resources" do
    create_manifest("edge-prebuilt" => true)

    manifest_file = home_file(".bosh_bootstrap", "manifest.yml")
    File.should be_exists(manifest_file)

    cmd.deploy

    ip_adresses = fog.addresses
    public_ips = ip_adresses.map(&:public_ip)

    inception_vms = provider.servers_with_sg("#{bosh_name}-inception-vm")
    inception_vms.size.should == 1

    # TODO inception VM is not getting its IP address bound correctly
    # https://github.com/StarkAndWayne/bosh-bootstrap/issues/174
    # public_ips.include?(inception_vms.first.public_ip_address).should be_true

    micrboshes = provider.servers_with_sg(bosh_name)
    micrboshes.size.should == 1
    public_ips.include?(micrboshes.first.public_ip_address).should be_true

    # TODO - no files in /var/vcap/store/stemcells (since it used AMI)
  end

end