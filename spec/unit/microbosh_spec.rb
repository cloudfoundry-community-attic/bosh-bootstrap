require "settingslogic"

describe Bosh::Bootstrap::Microbosh do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:path_or_ami) { "/path/to/stemcell.tgz" }
  let(:base_path) { File.expand_path("~/.microbosh") }
  let(:settings_dir) { base_path }
  let(:microbosh_provider) { stub(create_microbosh_yml: {}) }
  subject { Bosh::Bootstrap::Microbosh.new(base_path, microbosh_provider) }

  it "deploys new microbosh" do
    setting "bosh.stemcell", path_or_ami
    subject.stub(:sh).with("bundle install")
    subject.stub(:sh).with("bundle exec bosh micro deploy #{path_or_ami}")
    subject.deploy("aws", settings)
  end

  xit "updates existing microbosh" do
    subject.deploy
  end
  xit "re-deploys failed microbosh deployment" do
    subject.deploy
  end
end