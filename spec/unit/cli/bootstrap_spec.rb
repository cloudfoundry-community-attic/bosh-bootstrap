# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "bosh-bootstrap/cli/commands/deploy"
require "bosh-bootstrap/cli/commands/ssh"
describe Bosh::Cli::Command::Bootstrap do
  include FileUtils

  before do
    FileUtils.mkdir_p(@stemcells_dir = File.join(Dir.mktmpdir, "stemcells"))
    FileUtils.mkdir_p(@cache_dir = File.join(Dir.mktmpdir, "cache"))
  end

  let(:cli) do
    cli = Bosh::Cli::Command::Bootstrap.new(nil)
    cli.add_option(:non_interactive, true)
    cli.add_option(:cache_dir, @cache_dir)
    cli
  end

  it "runs deploy command" do
    cmd = double(Bosh::Bootstrap::Cli::Commands::Deploy)
    cmd.should_receive(:perform)
    Bosh::Bootstrap::Cli::Commands::Deploy.stub(:new).and_return(cmd)
    cli.deploy
  end

  it "runs ssh command" do
    cmd = double(Bosh::Bootstrap::Cli::Commands::SSH)
    cmd.should_receive(:perform)
    Bosh::Bootstrap::Cli::Commands::SSH.stub(:new).and_return(cmd)
    cli.ssh
  end
end