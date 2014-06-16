require "bosh-bootstrap/key_pair"

describe Bosh::Bootstrap::KeyPair do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  subject { Bosh::Bootstrap::KeyPair.new(settings_dir, "keyname", "PRIVATE") }

  it "creates local private key file" do
    setup_home_dir
    expect(home_file(".microbosh", "ssh", "keyname")).to be_exists
    subject.execute!
    keyfile = home_file(".microbosh", "ssh", "keyname")
    File.read(keyfile).should == "PRIVATE"
  end
end
