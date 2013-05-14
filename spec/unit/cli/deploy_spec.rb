# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "bosh-bootstrap/cli/commands/deploy"
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

  it "runs Deploy command" do
    deploy_cmd = double(Bosh::Bootstrap::Cli::Commands::Deploy)
    deploy_cmd.stub(:perform)
    Bosh::Bootstrap::Cli::Commands::Deploy.stub(:new).and_return(deploy_cmd)
    cli.deploy
  end
end