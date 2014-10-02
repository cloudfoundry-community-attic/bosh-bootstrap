# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "bosh-bootstrap/cli/commands/delete"

describe Bosh::Bootstrap::Cli::Commands::Delete do
  include StdoutCapture
  include Bosh::Bootstrap::Cli::Helpers

  let(:settings_dir) { File.expand_path("~/.microbosh") }

  subject { Bosh::Bootstrap::Cli::Commands::Delete.new }

  it "deletes microbosh VM" do
    setting "bosh.name", "test-bosh"
    mkdir_p(File.join(settings_dir, "deployments"))
    subject.should_receive(:sh).with("bosh -n micro deployment test-bosh")
    subject.should_receive(:sh).with("bosh -n micro delete")
    subject.perform
  end
end
