require "readwritesettings"
require "fakeweb"
require "bosh-bootstrap/microbosh_providers/aws"

describe Bosh::Bootstrap::MicroboshProviders::AWS do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}
  let(:aws_jenkins_bucket) { "bosh-jenkins-artifacts" }
  let(:latest_ami_uri) { "http://#{aws_jenkins_bucket}.s3.amazonaws.com/last_successful_micro-bosh-stemcell-aws_ami_us-east-1" }
  let(:latest_stemcell_uri) { "http://#{aws_jenkins_bucket}.s3.amazonaws.com/last_successful_micro-bosh-stemcell-aws.tgz" }

  it "creates micro_bosh.yml manifest" do
    setting "provider.name", "aws"
    setting "provider.region", "us-west-2"
    setting "provider.credentials.aws_access_key_id", "ACCESS"
    setting "provider.credentials.aws_secret_access_key", "SECRET"
    setting "address.ip", "1.2.3.4"
    setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
    setting "bosh.name", "test-bosh"
    setting "bosh.salted_password", "salted_password"
    setting "bosh.persistent_disk", 16384

    subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)

    subject.create_microbosh_yml(settings)
    File.should be_exists(microbosh_yml)
    yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.aws_ec2.yml"))
  end

  it "supports explicit provider.az" do
    setting "provider.az", "us-west-2a"
    setting "provider.name", "aws"
    setting "provider.region", "us-west-2"
    setting "provider.credentials.aws_access_key_id", "ACCESS"
    setting "provider.credentials.aws_secret_access_key", "SECRET"
    setting "address.ip", "1.2.3.4"
    setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
    setting "bosh.name", "test-bosh"
    setting "bosh.salted_password", "salted_password"
    setting "bosh.persistent_disk", 16384

    subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)

    subject.create_microbosh_yml(settings)
    File.should be_exists(microbosh_yml)
    yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.aws_ec2.us-west-2a.yml"))
  end

  describe "stemcell" do
    before do
      setting "provider.name", "aws"
    end

    it "is an AMI if us-east-1 target region" do
      setting "provider.region", "us-east-1"
      FakeWeb.register_uri(:get, latest_ami_uri, body: "ami-234567")

      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)
      subject.stemcell.should == "ami-234567"
    end

    it "retries to get AMI if initially fails" do
      setting "provider.region", "us-east-1"
      FakeWeb.register_uri(:get, latest_ami_uri, [
        { status: 404 },
        { body: "ami-234567"}
      ])

      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)
      subject.stemcell.should == ""
      subject.stemcell.should == "ami-234567"
    end

    xit "errors if AMI not available and not running within target region" do
      setting "provider.region", "us-west-2"
    end

    it "downloads latest stemcell and returns path if running in target AWS region" do
      setting "provider.region", "us-west-2"
      
      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)
      subject.stub(:sh).with("curl -O '#{latest_stemcell_uri}'")
      subject.stemcell.should =~ %r{deployments/last_successful_micro-bosh-stemcell-aws.tgz$}
    end
  end
end
