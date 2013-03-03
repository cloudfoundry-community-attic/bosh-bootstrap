# Copyright (c) 2012-2013 Stark & Wayne, LLC

require File.expand_path("../../spec_helper", __FILE__)

# Specs for 'ssh' related behavior. Includes CLI commands:
# * ssh
# * tmux
# * mosh
describe Bosh::Bootstrap do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter

  before do
    ENV['MANIFEST'] = File.join(ENV['HOME'], "manifest.yml")
    rm_rf(ENV['MANIFEST'])
    @cmd = Bosh::Bootstrap::Cli.new
  end

  # used by +SettingsSetter+ to access the settings
  def settings
    @cmd.settings
  end

  describe "ssh" do
    before do
      setting "inception.host", "5.5.5.5"
      setting "inception.key_pair.private_key", "PRIVATE"
      setting "inception.key_pair.public_key", "PUBLIC"
      @private_key_path = File.join(ENV['HOME'], ".ssh", "inception")
    end

    describe "normal" do
      it "launches ssh session" do
        @cmd.should_receive(:exit)
        @cmd.should_receive(:system).
          with("ssh -i #{@private_key_path} vcap@5.5.5.5")
        @cmd.ssh
      end
      it "runs ssh command" do
        @cmd.should_receive(:exit)
        @cmd.should_receive(:system).
          with("ssh -i #{@private_key_path} vcap@5.5.5.5 'some command'")
        @cmd.ssh("some command")
      end
    end

    describe "tmux" do
      it "launches ssh session" do
        @cmd.should_receive(:exit)
        @cmd.should_receive(:system).
          with("ssh -i #{@private_key_path} vcap@5.5.5.5 -t 'tmux attach || tmux new-session'")
        @cmd.tmux
      end
    end

    describe "mosh" do
      before do
        @cmd.settings['bosh_provider'] = 'aws'
        Fog.mock!
        fog_compute = Fog::Compute.new(
          :provider  => 'AWS', 
          :aws_access_key_id  => 'MOCK_AWS_ACCESS_KEY_ID',
          :aws_secret_access_key  => 'MOCK_AWS_SECRET_ACCESS_KEY')
        @cmd.stub!(:provider).and_return(Bosh::Providers.for_bosh_provider_name('aws', fog_compute))
        @cmd.stub!(:fog_compute).and_return(fog_compute)
        @cmd.fog_compute.stub!(:servers).and_return(double(:get => double(:groups => ['default'])))
      end
      after do
        Fog.unmock!
      end
      it "should check whether mosh is installed" do
         @cmd.should_receive(:system).
          with("mosh --version")
        @cmd.stub!(:exit)
        @cmd.ensure_mosh_installed
      end
      it "launches mosh session" do
        @cmd.stub!(:ensure_mosh_installed).and_return(true)
        @cmd.should_receive(:exit)
        @cmd.should_receive(:system).
          with("mosh vcap@5.5.5.5")
        @cmd.mosh
      end
      it "should ensure that the mosh ports are opened" do
        expected_ports = {
          mosh: { 
            protocol: "udp", 
            ports: (60000..60050) 
          }
        } 
        @cmd.provider.stub!(:create_security_group)
          .with('default','not used', expected_ports)
        @cmd.ensure_security_group_allows_mosh
      end
    end
  end
end
