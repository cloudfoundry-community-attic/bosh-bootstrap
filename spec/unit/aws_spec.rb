require File.expand_path("../../spec_helper", __FILE__)

require "active_support/core_ext/hash/keys"

describe "AWS deployment" do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter

  before do
    Fog.mock!
    Fog::Mock.reset
    @cmd = Bosh::Bootstrap::Cli.new
    @fog_credentials = {
      :provider                 => 'AWS',
      :aws_secret_access_key    => 'XXX',
      :aws_access_key_id        => 'YYY'
    }

    @region = "us-west-2"
    setting "bosh_provider", "aws"
    setting "region_code", @region
    setting "bosh_name", "test-bosh"
    setting "inception.create_new", true
    setting "bosh_username", "testuser"
    setting "bosh_password", "testpass"
    setting "fog_credentials", @fog_credentials.stringify_keys
    setting "bosh.salted_password", "pepper"
    setting "bosh.persistent_disk", 16384
    setting "git.name", "Dr Nic Williams"
    setting "git.email", "drnicwilliams@gmail.com"
  end

  # used by +SettingsSetter+ to access the settings
  def settings
    @cmd.settings
  end

  def fog
    @fog ||= connection = Fog::Compute.new(@fog_credentials.merge(:region => @region))
  end

  def expected_manifest_content(filename, public_ip, subnet_id = nil)
    file = File.read(filename)
    file.gsub!('$MICROBOSH_IP$', public_ip)
    file.gsub!('$SUBNET_ID$', subnet_id) if subnet_id
    YAML.load(file)
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
    @cmd.should_receive(:deploy_stage_7_setup_new_bosh)
    @cmd.deploy

    fog.addresses.should have(1).item # assigned to inception VM
    inception_ip_address = fog.addresses.first

    fog.vpcs.should have(1).item
    vpc = fog.vpcs.first
    vpc.cidr_block.should == "10.0.0.0/16"

    fog.servers.should have(1).item
    inception = fog.servers.first
    inception_ip_address.domain.should == "vpc"

    # TODO - fix fog so we can test public_ip_address
    # inception.public_ip_address.should == inception_ip_address.public_ip

    # TODO - fix fog so we can test private_ip_address
    # inception.private_ip_address.should == "10.0.0.5"

    fog.security_groups.should have(3).item

    fog.internet_gateways.should have(1).item
    ig = fog.internet_gateways.first

    fog.subnets.should have(1).item
    subnet = fog.subnets.first
    subnet.vpc_id.should == vpc.id
    subnet.cidr_block.should == "10.0.0.0/24"

    # fog.route_tables.should have(1).item
    # a IG that is assigned to the VPN
    # a subnet (contains the inception VM; is included in micro_bosh_yml)

    # TODO - fix fog so we can test private_ip_address
    # settings["inception"]["ip_address"].should == "10.0.0.5"

    inception_server = fog.servers.first
    inception_server.dns_name.should == settings["inception"]["host"]
    inception_server.groups.should == [settings["inception"]["security_group"]]

    public_ip = settings["bosh"]["ip_address"]
    public_ip.should == "10.0.0.6"

    manifest_path = spec_asset("micro_bosh_yml/micro_bosh.aws_ec2.yml")
    YAML.load(@cmd.micro_bosh_yml).should == expected_manifest_content(manifest_path, public_ip, subnet.subnet_id)
  end

  it "creates an EC2 inception/microbosh with the associated resources" do
    setting "use_vpc", false

    @cmd.should_receive(:provision_and_mount_volume)
    @cmd.stub(:run_server).and_return(true)
    @cmd.stub(:sleep)
    @cmd.should_receive(:deploy_stage_7_setup_new_bosh)
    @cmd.deploy
    @settings = nil # reload settings file

    fog.addresses.should have(2).item
    inception_ip_address = fog.addresses.first
    inception_ip_address.domain.should == "standard"

    inception_kp = fog.key_pairs.find { |kp| kp.name == "inception" }
    inception_kp.should_not be_nil

    inception_kp = fog.key_pairs.find { |kp| kp.name == "fog_default" }
    inception_kp.should be_nil

    fog.key_pairs.should have(2).item

    settings["inception"].should_not be_nil
    settings["inception"]["key_pair"].should_not be_nil
    settings["inception"]["key_pair"]["name"].should_not be_nil
    settings["inception"]["key_pair"]["private_key"].should_not be_nil
    settings["inception"]["local_private_key_path"].should == File.join(ENV['HOME'], ".bosh_bootstrap", "ssh", "inception")
    File.should_not be_world_readable(settings["inception"]["local_private_key_path"])

    fog.vpcs.should have(0).item
    fog.servers.should have(1).item
    fog.security_groups.should have(3).item

    inception_server = fog.servers.first
    inception_server.dns_name.should == settings["inception"]["host"]
    inception_server.groups.should == [settings["inception"]["security_group"]]
    
    public_ip = settings["bosh"]["ip_address"]
    manifest_path = spec_asset("micro_bosh_yml/micro_bosh.aws_ec2.yml")
    YAML.load(@cmd.micro_bosh_yml).should == expected_manifest_content(manifest_path, public_ip)
  end

  it "uses pre-built gems and AMIs for us-east-1 created from jenkins" do
    @cmd.should_receive(:provision_and_mount_volume)
    @cmd.stub(:run_server).and_return(true)
    @cmd.stub(:sleep)
    @cmd.should_receive(:deploy_stage_7_setup_new_bosh)
    @cmd.should_receive(:latest_prebuilt_microbosh_ami).and_return("ami-123456")

    setting "edge-prebuilt", true
    @cmd.deploy

    settings["bosh_rubygems_source"].should == "https://s3.amazonaws.com/bosh-jenkins-gems/"
    settings["micro_bosh_stemcell_type"].should == "ami"
    settings["micro_bosh_stemcell_name"].should == "ami-123456"
    settings["bosh_stemcell_url"].should == "http://bosh-jenkins-artifacts.s3.amazonaws.com/last_successful_bosh-stemcell_light.tgz"

    public_ip = settings["bosh"]["ip_address"]
    manifest_path = spec_asset("micro_bosh_yml/micro_bosh.aws_ec2.yml")
    YAML.load(@cmd.micro_bosh_yml).should == expected_manifest_content(manifest_path, public_ip)
  end
end