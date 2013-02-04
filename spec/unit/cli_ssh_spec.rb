# Copyright (c) 2012-2013 Stark & Wayne, LLC

require File.expand_path("../../spec_helper", __FILE__)

# Specs for 'ssh' related behavior. Includes CLI commands:
# * ssh
# * tmux
# * mosh
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

    describe "mosh" do
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
    end
  end
end
