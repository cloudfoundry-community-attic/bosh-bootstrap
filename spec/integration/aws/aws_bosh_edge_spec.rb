require File.expand_path("../../../spec_helper", __FILE__)
require File.expand_path("../aws_helpers", __FILE__)

require "active_support/core_ext/hash/keys"

describe "AWS deployment using Bosh edge from source" do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter
  include AwsHelpers

  attr_reader :bosh_name

  before { prepare_aws("bosh-edge", aws_region) }
  after { destroy_test_constructs(bosh_name) unless keep_after_test? }

  def aws_region
    ENV['AWS_REGION'] || "us-west-2"
  end

  it "creates an EC2 inception/microbosh with the associated resources" do
    create_manifest(
      "bosh_git_source" => true,
      "micro_bosh_stemcell_type" => "custom",
      "micro_bosh_stemcell_name" => "custom"
    )

    manifest_file = home_file(".bosh_bootstrap", "manifest.yml")
    File.should be_exists(manifest_file)

    cmd.deploy

    fog.addresses.should have(2).item
    inception_ip_address = fog.addresses.first
    inception_ip_address.domain.should == "standard"

    inception_vms = servers_with_sg("#{bosh_name}-inception-vm")
    inception_vms.size.should == 1

    micrboshes = servers_with_sg(bosh_name)
    micrboshes.size.should == 1
  end

end