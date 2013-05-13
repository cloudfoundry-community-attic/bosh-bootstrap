describe "AWS deployment using gems and publish stemcells" do
  include FileUtils

  before { prepare_aws_test }
  after { destroy_test_constructs }

  xit "creates an EC2 inception/microbosh with the associated resources" do
    create_manifest
    cmd.deploy

    # creates a server with a specific tagged name
    # server has a 16G volume attached (plus a root volume)
    # IP was provisioned
    # IP was attached to server
  end

  it "EC2 microbosh from latest AMI"
  it "EC2 microbosh from latest stemcell"
  it "EC2 microbosh from source"

end
