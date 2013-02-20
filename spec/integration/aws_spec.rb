require File.expand_path("../../spec_helper", __FILE__)

require "active_support/core_ext/hash/keys"

describe "AWS deployment" do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter

  before do
    setup_home_dir
  end

  def fog_credentials
    @fog_credentials ||= begin
      access_key = ENV['AWS_ACCESS_KEY_ID']
      secret_key = ENV["AWS_SECRET_ACCESS_KEY"]
      unless access_key & secret_key
        raise "Please provided $AWS_ACCESS_KEY_ID and $AWS_SECRET_ACCESS_KEY"
      end
      credentials = {
        :provider                 => 'AWS',
        :aws_access_key_id        => access_key,
        :aws_secret_access_key    => secret_key
      }
    end
  end
  def create_manifest(options = {})

    settings = {
      "bosh_provider" => "aws",
      "region_code" => "us-west-2",
      "bosh_name" => "test-bosh",
      "inception" => {
        "create_new" => true,
      },
      "bosh_username" => "testuser",
      "bosh_password" => "testpass",
      "bosh.password" => "testpass",
      "fog_credentials" => fog_credentials.stringify_keys,
      "bosh.salted_password" => "pepper",
      "bosh.persistent_disk" => 16384
    }
    mkdir_p(home_file(".bosh_bootstrap"))
    File.open(home_file(".bosh_bootstrap", "manifest.yml"), "w") do |file|
      file << settings.merge(options.stringify_keys).to_yaml
    end
  end
  it "creates an EC2 inception/microbosh with the associated resources" do
    create_manifest(vpc: false)

    manifest_file = home_file(".bosh_bootstrap", "manifest.yml")
    File.should be_exists(manifest_file)
    YAML.load_file(manifest_file)["vpc"].should == false

    # @cmd.deploy
    #
    #
    #
    # fog.addresses.should have(2).item
    # inception_ip_address = fog.addresses.first
    # inception_ip_address.domain.should == "standard"
    #
    # fog.vpcs.should have(0).item
    # fog.servers.should have(2).item
    # fog.security_groups.should have(2).item
    # fog.keypairs.should have(2).item
  end

end