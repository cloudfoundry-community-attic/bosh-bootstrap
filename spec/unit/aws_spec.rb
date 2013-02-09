require File.expand_path("../../spec_helper", __FILE__)

require "active_support/core_ext/hash/keys"

describe "AWS deployment" do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter

  before do
    Fog.mock!
    ENV['MANIFEST'] = File.expand_path("../../../tmp/test-manifest.yml", __FILE__)
    rm_rf(ENV['MANIFEST'])
    @cmd = Bosh::Bootstrap::Cli.new
    @fog_credentials = {
      :provider                 => 'AWS',
      :aws_secret_access_key    => 'XXX',
      :aws_access_key_id        => 'YYY'
    }

    setting "bosh_provider", "aws"
    setting "region_code", "us-west-2"
    setting "bosh_name", "test-bosh"
    setting "inception.create_new", true
    setting "bosh_username", "testuser"
    setting "bosh_password", "testpass"
    setting "bosh.password", "testpass"
    setting "fog_credentials", @fog_credentials.stringify_keys
    setting "bosh.salted_password", "pepper"
    setting "bosh.persistent_disk", 16384
  end

  # used by +SettingsSetter+ to access the settings
  def settings
    @cmd.settings
  end

  def fog
    @fog ||= connection = Fog::Compute.new(@fog_credentials.merge(:region => "us-west-2"))
  end

  def expected_manifest_content(filename, public_ip)
    YAML.load(File.read(filename).gsub('$MICROBOSH_IP$', public_ip))
  end

  xit "creates a VPC inception/microbosh with the associated resources" do
    # create a VPC
    # create a BOSH subnet 10.10.0.0/24
    # create BOSH security group
    # create INCEPTION security group allowing only 22
    # create NATS security group, allowing only 4222
    # create DHCP options with 2 nameserver (1 amazon for public resolves, 1 for private resolves (.bosh)?)
    # create Internet Gateway, attach to VPC
    # create default route (0.0.0.0/0) to IG

    # create inception VM (attaching elastic IP, sg of [BOSH, INCEPTION]) in BOSH subnet at 10.10.0.5
    # create MB VM from inception VM (sg of [BOSH, NATS])  in BOSH subnet at 10.10.0.6

    setting "use_vpc", true # TODO include in cli.rb

    @cmd.should_receive(:provision_and_mount_volume)
    @cmd.stub(:run_server).and_return(true)
    @cmd.stub(:sleep)
    @cmd.should_receive(:deploy_stage_6_setup_new_bosh)
    @cmd.deploy

    fog.vpcs.should have(1).item
  end

  it "creates an EC2 inception/microbosh with the associated resources" do
    setting "use_vpc", false

    @cmd.should_receive(:provision_and_mount_volume)
    @cmd.stub(:run_server).and_return(true)
    @cmd.stub(:sleep)
    @cmd.should_receive(:deploy_stage_6_setup_new_bosh)
    @cmd.deploy

    fog.vpcs.should have(0).item
    fog.servers.should have(1).item
    fog.security_groups.should have(2).item
    fog.addresses.should have(2).item
    inception_server = fog.servers.first
    inception_server.dns_name.should == settings["inception"]["host"]
    public_ip = settings["bosh"]["ip_address"]
    manifest_path = spec_asset("micro_bosh_yml/micro_bosh.aws_ec2.yml")
    YAML.load(@cmd.micro_bosh_yml).should == expected_manifest_content(manifest_path, public_ip)
  end
end