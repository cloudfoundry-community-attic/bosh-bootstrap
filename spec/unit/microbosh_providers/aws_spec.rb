require "readwritesettings"
require "fakeweb"
require "bosh-bootstrap/microbosh_providers/aws"

describe Bosh::Bootstrap::MicroboshProviders::AWS do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml") }
  let(:artifacts_base) { "https://bosh-jenkins-artifacts.s3.amazonaws.com" }
  let(:http_client) { instance_double("HTTPClient") }

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
    expect(File).to be_exists(microbosh_yml)
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
    expect(File).to be_exists(microbosh_yml)
    yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.aws_ec2.us-west-2a.yml"))
  end

  it "creates micro_bosh.yml manifest" do
    setting "provider.name", "aws"
    setting "provider.region", "us-west-2"
    setting "provider.credentials.aws_access_key_id", "ACCESS"
    setting "provider.credentials.aws_secret_access_key", "SECRET"
    setting "address.ip", "1.2.3.4"
    setting "address.vpc_id", "vpc-123456"
    setting "address.subnet_id", "subnet-123456"
    setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
    setting "bosh.name", "test-bosh"
    setting "bosh.salted_password", "salted_password"
    setting "bosh.persistent_disk", 16384

    subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)

    subject.create_microbosh_yml(settings)
    expect(File).to be_exists(microbosh_yml)
    yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.aws_vpc.yml"))
  end

  describe "stemcell" do
    before do
      setting "provider.name", "aws"
    end

    before(:each) do
      body = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>bosh-jenkins-artifacts</Name>
  <Prefix>bosh-stemcell</Prefix>
  <Marker/>
  <MaxKeys>1000</MaxKeys>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>bosh-stemcell/aws/bosh-stemcell-2719-aws-xen-centos-go_agent.tgz</Key>
    <LastModified>2014-09-22T04:59:16.000Z</LastModified>
    <ETag>"7621366406eeb0a9d88242a664206cc3"</ETag>
    <Size>557556059</Size>
    <StorageClass>STANDARD</StorageClass>
  </Contents>
  <Contents>
    <Key>bosh-stemcell/aws/bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz</Key>
    <LastModified>2014-09-22T04:59:16.000Z</LastModified>
    <ETag>"18cb27adc889e71c97e39b1c57f85027"</ETag>
    <Size>467288141</Size>
    <StorageClass>STANDARD</StorageClass>
  </Contents>
  <Contents>
    <Key>bosh-stemcell/aws/light-bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz</Key>
    <LastModified>2014-09-22T04:59:16.000Z</LastModified>
    <ETag>"28cb27adc889e71c97e39b1c57f85027"</ETag>
    <Size>467288141</Size>
    <StorageClass>STANDARD</StorageClass>
  </Contents>
</ListBucketResult>
      XML
      expect(Bosh::Bootstrap::PublicStemcells).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:get).
        with(artifacts_base, {'prefix' => 'bosh-stemcell'}).
        and_return(OpenStruct.new(body: body))
    end

    it "light stemcell if us-east-1 target region" do
      setting "provider.region", "us-east-1"

      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)

      latest_stemcell_uri = "#{artifacts_base}/bosh-stemcell/aws/" +
        "light-bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz"
      expect(subject).to receive(:sh).with("curl -O '#{latest_stemcell_uri}'")
      expect(subject).to receive(:find_ami_for_stemcell).
        with("bosh-aws-xen-ubuntu-trusty-go_agent", "2719").
        and_return(nil)

      expect(subject.stemcell_path).to match /light-bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz$/
    end

    it "downloads latest stemcell and returns path if running in target AWS region" do
      setting "provider.region", "us-west-2"

      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)

      latest_stemcell_uri = "#{artifacts_base}/bosh-stemcell/aws/" +
        "bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz"
      expect(subject).to receive(:sh).with("curl -O '#{latest_stemcell_uri}'")
      expect(subject).to receive(:find_ami_for_stemcell).
        with("bosh-aws-xen-ubuntu-trusty-go_agent", "2719").
        and_return(nil)

      stemcell_path = subject.stemcell_path
      expect(stemcell_path).to match /bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz$/
      expect(stemcell_path).to_not match /light-bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz$/
    end

    it "discovers pre-created AMI and uses it instead" do
      setting "provider.region", "us-west-2"

      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)

      expect(subject).to_not receive(:sh)
      expect(subject).to receive(:find_ami_for_stemcell).
        with("bosh-aws-xen-ubuntu-trusty-go_agent", "2719").and_return("ami-123456")

      stemcell_path = subject.stemcell_path
      expect(stemcell_path).to match /ami-123456$/
    end
  end

  describe "existing stemcells as AMIs" do
    before do
      setting "provider.region", "us-west-2"
    end

    it "finds match" do
      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)
      expect(subject).to receive(:owned_images).and_return([
        {
          "description" => "bosh-aws-xen-ubuntu-trusty-go_agent 2222",
          "imageId" => "ami-wrong-one"
        },
        {
          "description" => "bosh-aws-xen-ubuntu-trusty-go_agent 2732",
          "imageId" => "ami-123456"
        },
        {
          "description" => "bosh-aws-xen-ubuntu-trusty-go_agent 2732",
          "imageId" => "ami-some-other"
        }
      ])
      expect(subject.find_ami_for_stemcell("bosh-aws-xen-ubuntu-trusty-go_agent", "2732")).to eq "ami-123456"
    end

    it "doesn't find match" do
      subject = Bosh::Bootstrap::MicroboshProviders::AWS.new(microbosh_yml, settings)
      expect(subject).to receive(:owned_images).and_return([])
      expect(subject.find_ami_for_stemcell("xxxx", "12345")).to be_nil
    end
  end
end
