require "bosh-bootstrap/key_pair"

describe Bosh::Bootstrap::KeyPair do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  subject { Bosh::Bootstrap::KeyPair.new(work_dir, "keyname", "PRIVATE") }

  it "creates local private key file" do
    expect(File.exists?(work_file("ssh", "keyname"))).to eq false
    subject.execute!
    keyfile = work_file("ssh", "keyname")
    expect(File.read(keyfile)).to eq "PRIVATE"
  end
end
