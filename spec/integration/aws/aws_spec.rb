require File.expand_path("../../../spec_helper", __FILE__)

require "active_support/core_ext/hash/keys"

describe "AWS deployment" do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter

  before do
    setup_home_dir
    @cmd = nil
    @fog = nil
    destroy_test_constructs
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

  def aws_region
    ENV['AWS_REGION'] || "us-west-2"
  end

  def fog
    @fog ||= connection = Fog::Compute.new(fog_credentials.merge(:region => aws_region))
  end

  def cmd
    @cmd ||= Bosh::Bootstrap::Cli.new
  end

  # used by +SettingsSetter+ to access the settings
  def settings
    cmd.settings
  end

  def bosh_name
    "test-bosh"
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

  def destroy_test_constructs
    puts "Destroying everything created by previous tests..."
    # destroy servers using inception-vm SG
    delete_security_group_and_servers("#{bosh_name}-inception-vm")
    delete_security_group_and_servers(bosh_name)

    if kp = fog.key_pairs.find {|kp| kp.name == bosh_name}
      puts "Deleting key pair #{kp}..."
      kp.destroy
    end

    # TODO delete "inception" key pair? Why isn't it named for the bosh/inception VM?

    # fog.vpcs.each { |v| v.destroy } - must delete dependencies first

    # destroy all IP addresses that aren't bound to a server
    fog.addresses.each do |a|
      puts "Deleting IP address #{a}..."
      a.destroy unless a.server
    end
  end

  def delete_security_group_and_servers(sg_name)
    sg = fog.security_groups.find {|sg| sg.name == sg_name }
    if sg
      fog.servers.select {|s| s.security_group_ids.include? sg.group_id }.each do |server|
        puts "Destroying server #{server}..."
        server.destroy
      end
      begin
        puts "Destroying security group #{sg}..."
        sg.destroy
      rescue Fog::Compute::AWS::Error => e
        $stderr.puts e
      end
    end
  end

  def servers_with_sg(sg_name)
    inception_sg = fog.security_groups.find {|sg| sg.name == sg_name }
    if inception_sg
      fog.servers.select {|s| s.security_group_ids.include? inception_sg.group_id }
    else
      $stderr.puts "no security group #{sg_name} was found"
      []
    end
  end

  it "creates an EC2 inception/microbosh with the associated resources" do
    create_manifest("vpc" => false)

    manifest_file = home_file(".bosh_bootstrap", "manifest.yml")
    File.should be_exists(manifest_file)
    YAML.load_file(manifest_file)["vpc"].should == false

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