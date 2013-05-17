require "settingslogic"
require "bosh-bootstrap/microbosh_providers/aws"

describe Bosh::Bootstrap::MicroboshProviders::AWS do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}

  subject { Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml) }

  it "creates micro_bosh.yml manifest" do
    setting "provider.name", "aws"
    setting "provider.region", "us-west-2"
    setting "provider.credentials.aws_access_key_id", "ACCESS"
    setting "provider.credentials.aws_secret_access_key", "SECRET"
    setting "address.ip", "1.2.3.4"
    setting "bosh.name", "test-bosh"
    setting "bosh.salted_password", "salted_password"
    setting "bosh.persistent_disk", 16384

    subject.create_microbosh_yml(settings)
    File.should be_exists(microbosh_yml)
    files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.aws_ec2.yml"))
  end
end
