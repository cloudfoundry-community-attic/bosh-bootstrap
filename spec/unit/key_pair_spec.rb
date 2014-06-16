require "bosh-bootstrap/key_pair"

describe Bosh::Bootstrap::KeyPair do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  subject { Bosh::Bootstrap::KeyPair.new(settings_dir, "keyname", "PRIVATE") }

  it "creates local private key file" do
    setup_home_dir
    expect(File.exists?(home_file(".microbosh", "ssh", "keyname"))).to eq false
    subject.execute!
    keyfile = home_file(".microbosh", "ssh", "keyname")
    expect(File.read(keyfile)).to eq "PRIVATE"
  end
end
