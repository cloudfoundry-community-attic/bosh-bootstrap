require "settingslogic"

describe Bosh::Bootstrap::Microbosh do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:path_or_ami) { "/path/to/stemcell.tgz" }
  let(:base_path) { File.expand_path("~/.microbosh") }
  let(:settings_dir) { base_path }
  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}
  subject { Bosh::Bootstrap::Microbosh.new(base_path, path_or_ami) }

  describe "aws" do
    before do
      setting "provider.name", "aws"
      setting "provider.region", "us-west-2"
      setting "provider.credentials.aws_access_key_id", "ACCESS"
      setting "provider.credentials.aws_secret_access_key", "SECRET"
      setting "bosh.name", "test-bosh"
      setting "bosh.password", "password"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.public_ip", "1.2.3.4"
      setting "bosh.persistent_disk", 16384
      subject.stub(:sh).with("bundle install")
      subject.stub(:sh).with("bundle exec bosh micro deploy #{path_or_ami}")
    end

    it "deploys new microbosh" do
      subject.deploy("aws", settings)
      File.should be_exists(microbosh_yml)
      files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.aws_ec2.yml"))
    end
  end
  xit "updates existing microbosh" do
    subject.deploy
  end
  xit "re-deploys failed microbosh deployment" do
    subject.deploy
  end
end