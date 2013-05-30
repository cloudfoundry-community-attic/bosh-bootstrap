# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "bosh-bootstrap/cli/commands/ssh"

describe Bosh::Bootstrap::Cli::Commands::SSH do
  include StdoutCapture
  include Bosh::Bootstrap::Cli::Helpers

  let(:settings_dir) { File.expand_path("~/.microbosh") }

  subject { Bosh::Bootstrap::Cli::Commands::SSH.new }

  it "runs ssh" do
    setting "address.ip", "1.2.3.4"
    setting "key_pair.path", "/path/to/private/key"
    subject.should_receive(:setup_keypair)
    subject.should_receive(:sh).with("ssh -i /path/to/private/key vcap@1.2.3.4")
    subject.perform
  end
end