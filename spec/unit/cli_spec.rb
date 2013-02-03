# Copyright (c) 2012-2013 Stark & Wayne, LLC

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Bootstrap do
  include FileUtils

  before do
    ENV['MANIFEST'] = File.expand_path("../../../tmp/test-manifest.yml", __FILE__)
    rm_rf(ENV['MANIFEST'])
    @cmd = Bosh::Bootstrap::Cli.new
  end

  describe "ssh" do
    before do
      @cmd.settings["inception"] = {}
      @cmd.settings["inception"]["host"] = "5.5.5.5"
    end

    describe "normal" do
      it "launches ssh session" do
        @cmd.should_receive(:exit)
        @cmd.should_receive(:system).
          with("ssh vcap@5.5.5.5")
        @cmd.ssh
      end
      it "runs ssh command" do
        @cmd.should_receive(:exit)
        @cmd.should_receive(:system).
          with("ssh vcap@5.5.5.5 'some command'")
        @cmd.ssh("some command")
      end
    end

    describe "tmux" do
      it "launches ssh session" do
        @cmd.should_receive(:exit)
        @cmd.should_receive(:system).
          with("ssh vcap@5.5.5.5 -t 'tmux attach || tmux new-session'")
        @cmd.tmux
      end
    end
  end

  describe "micro_bosh_stemcell_name" do
    # The +bosh_stemcells_cmd+ has an output that looks like:
    # +-----------------------------------+--------------------+
    # | Name                              | Tags               |
    # +-----------------------------------+--------------------+
    # | micro-bosh-stemcell-aws-0.6.4.tgz | aws, micro, stable |
    # | micro-bosh-stemcell-aws-0.7.0.tgz | aws, micro, test   |
    # | micro-bosh-stemcell-aws-0.8.1.tgz | aws, micro, test   |
    # +-----------------------------------+--------------------+
    #
    # So to get the latest version for the filter tags,
    # get the Name field, reverse sort, and return the first item
    it "should return the latest stable stemcell by default for AWS" do
      @cmd.micro_bosh_stemcell_name.should == "micro-bosh-stemcell-aws-0.8.1.tgz"
    end
  end

end
