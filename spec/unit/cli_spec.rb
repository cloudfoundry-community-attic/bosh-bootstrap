# Copyright (c) 2012-2013 Stark & Wayne, LLC

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

  describe "aws" do
    it "deploy creates provisions IP address micro_bosh.yml, discovers/downloads stemcell/AMI, runs 'bosh micro deploy'"
    it "delete does nothing if not targetting a deployment"
    it "delete runs 'bosh micro delete' & releases IP address; updates settings"
  end
end