describe Bosh::Bootstrap::KeyPair do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  subject { Bosh::Bootstrap::KeyPair.new(settings_dir, "keyname", "PRIVATE") }

  it "creates local private key file" do
    setup_home_dir
    File.should_not be_exists(home_file(".microbosh", "ssh", "keyname"))
    subject.execute!
    keyfile = home_file(".microbosh", "ssh", "keyname")
    File.read(keyfile).should == "PRIVATE"
  end
end