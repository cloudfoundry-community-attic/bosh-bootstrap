require File.expand_path("../../../spec_helper", __FILE__)

require "active_support/core_ext/hash/keys"

describe "AWS deployment using Bosh edge from source" do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter

  attr_reader :bosh_name

  before do
    setup_home_dir
    @cmd = nil
    @fog = nil
    @bosh_name = "aws_bosh_edge-#{aws_region}-#{Random.rand(100000)}"
    create_manifest
    destroy_test_constructs(bosh_name)
  end

  after do
    destroy_test_constructs(bosh_name) unless keep_after_test?
  end

  def fog_credentials
    @fog_credentials ||= begin
      access_key = ENV['AWS_ACCESS_KEY_ID']
      secret_key = ENV["AWS_SECRET_ACCESS_KEY"]
      unless access_key && secret_key
        raise "Please provided $AWS_ACCESS_KEY_ID and $AWS_SECRET_ACCESS_KEY"
      end
      credentials = {
        :provider                 => 'AWS',
        :aws_access_key_id        => access_key,
        :aws_secret_access_key    => secret_key
      }
    end
  end

  def keep_after_test?
    ENV['KEEP_AFTER_TEST']
  end

  def aws_region
    ENV['AWS_REGION'] || "us-west-2"
  end

  def fog
    @fog ||= connection = Fog::Compute.new(fog_credentials.merge(:region => aws_region))
  end

  def cmd
    @cmd ||= Bosh::Bootstrap::Cli.new
  end

  def provider
    cmd.provider
  end

  # used by +SettingsSetter+ to access the settings
  def settings
    cmd.settings
  end

  def create_manifest(options = {})
    setting "bosh_provider", "aws"
    setting "region_code", aws_region
    setting "bosh_name", bosh_name
    setting "inception.create_new", true
    setting "bosh_username", "testuser"
    setting "bosh_password", "testpass"
    setting "fog_credentials", fog_credentials.stringify_keys
    setting "bosh.salted_password", "pepper"
    setting "bosh.persistent_disk", 16384
    setting "git.name", "Dr Nic Williams"
    setting "git.email", "drnicwilliams@gmail.com"
    options.each { |key, value| setting(key, value) }
    cmd.save_settings!
  end

  def destroy_test_constructs(bosh_name)
    puts "Destroying everything created by previous tests..."
    # destroy servers using inception-vm SG
    provider.delete_security_group_and_servers("#{bosh_name}-inception-vm")
    provider.delete_security_group_and_servers(bosh_name)

    # TODO delete "inception" key pair? Why isn't it named for the bosh/inception VM?
    provider.delete_key_pair(bosh_name)

    provider.cleanup_unused_ip_addresses
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