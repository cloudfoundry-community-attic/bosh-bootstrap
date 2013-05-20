# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "bosh-bootstrap/cli/commands/deploy"
require "cyoi/providers/clients/aws_provider_client"
describe Bosh::Bootstrap::Cli::Commands::Deploy do
  include Bosh::Bootstrap::Cli::Helpers

  let(:settings_dir) { File.expand_path("~/.microbosh") }

  before do
    FileUtils.mkdir_p(@stemcells_dir = File.join(Dir.mktmpdir, "stemcells"))
    FileUtils.mkdir_p(@cache_dir = File.join(Dir.mktmpdir, "cache"))
  end

  let(:cmd) do
    cmd = Bosh::Bootstrap::Cli::Commands::Deploy.new
    cmd
  end

  # * select_provider
  # * select_or_provision_public_networking # public_ip or ip/network/gateway
  # * select_public_image_or_download_stemcell # download if stemcell
  # * create_microbosh_manifest
  # * microbosh_deploy
  describe "aws" do
    it "deploy creates provisions IP address micro_bosh.yml, discovers/downloads stemcell/AMI, runs 'bosh micro deploy'" do
      setting "provider.name", "aws"
      provider = double(Cyoi::Cli::Provider)
      provider.stub(:execute!)
      Cyoi::Cli::Provider.should_receive(:new).with([settings_dir]).and_return(provider)

      provider_client = double(Cyoi::Providers::Clients::AwsProviderClient)
      provider_client.stub(:create_security_group)
      cmd.stub(:provider_client).and_return(provider_client)

      address = double(Cyoi::Cli::Address)
      address.stub(:execute!)
      Cyoi::Cli::Address.should_receive(:new).with([settings_dir]).and_return(address)

      microbosh_provider = stub(stemcell: "ami-123456")
      cmd.stub(:microbosh_provider).and_return(microbosh_provider)

      key_pair = double(Cyoi::Cli::KeyPair)
      key_pair.stub(:execute!)
      Cyoi::Cli::KeyPair.should_receive(:new).with([settings_dir]).and_return(key_pair)

      microbosh = double(Bosh::Bootstrap::Microbosh)
      microbosh.stub(:deploy)
      Bosh::Bootstrap::Microbosh.stub(:new).with(settings_dir, microbosh_provider).and_return(microbosh)

      cmd.perform
    end
    it "delete does nothing if not targetting a deployment"
    it "delete runs 'bosh micro delete' & releases IP address; updates settings"
  end
end