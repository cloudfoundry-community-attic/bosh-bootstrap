# Copyright (c) 2012-2013 Stark & Wayne, LLC

require File.expand_path("../../spec_helper", __FILE__)

# Specs for 'upgrade' command
describe Bosh::Bootstrap do
  include FileUtils
  include Bosh::Bootstrap::Helpers::SettingsSetter

  # used by +SettingsSetter+ to access the settings
  def settings
    @cmd.settings
  end

  before do
    @cmd = Bosh::Bootstrap::Cli.new
  end

  it "runs 'upgrade' command on an existing inception VM" do
    setting "inception.prepared", true
    setting "inception.username", "ubuntu"
    setting "git.name", "Dr Nic Williams"
    setting "git.email", "drnicwilliams@gmail.com"
    setting "bosh.password", "UNSALTED"
    setting "bosh.salted_password", "SALTED"
    @cmd.should_receive(:run_server).and_return(true)
    @cmd.upgrade_inception
  end
end
