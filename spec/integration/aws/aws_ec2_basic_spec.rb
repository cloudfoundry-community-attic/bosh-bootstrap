require File.expand_path("../aws_helpers", __FILE__)
describe "AWS deployment using gems and publish stemcells" do
  include Bosh::Bootstrap::Cli::Helpers::Settings
  include AwsHelpers

  let(:cli) do
    cli = Bosh::Cli::Command::Bootstrap.new(nil)
    cli.add_option(:non_interactive, true)
    cli.add_option(:cache_dir, @cache_dir)
    cli
  end

  # after { destroy_test_constructs }

  it "creates an EC2 inception/microbosh with the associated resources" do
    setup_home_dir
    create_manifest
    cli.deploy

    # creates ~/.microbosh/settings.yml
    # creates ~/.microbosh/Gemfile
    # creates ~/.microbosh/ssh/microbosh-test-bosh
    # creates ~/.microbosh/deployments/test-bosh/micro_bosh.yml

    # creates a server with a specific tagged name
    # server has a 16G volume attached (plus a root volume)
    # IP was provisioned
    # IP was attached to server
  end

  it "EC2 microbosh from latest AMI"
  it "EC2 microbosh from latest stemcell"
  it "EC2 microbosh from source"

end
