# Copyright (c) 2012-2013 Stark & Wayne, LLC

require File.expand_path("../../../../spec_helper", __FILE__)

# Specs for the aws provider
describe Bosh::Providers do
  include FileUtils

  describe "AWS" do
    before do
      Fog.mock!
      @fog_compute =  Fog::Compute.new(
          :provider  => 'AWS', 
          :aws_access_key_id  => 'MOCK_AWS_ACCESS_KEY_ID',
          :aws_secret_access_key  => 'MOCK_AWS_SECRET_ACCESS_KEY')
      @aws_provider ||= Bosh::Providers.for_bosh_provider_name("aws", @fog_compute)
    end

    describe "create security group" do
      it "should open a single TCP port on a security group" do
        ports = { ssh: 22 }
        @aws_provider.create_security_group("sg1-name", "sg1-desc", ports)
        created_sg = @fog_compute.security_groups.get("sg1-name")
        created_sg.name.should == "sg1-name"
        created_sg.description.should == "sg1-desc"
        created_sg.ip_permissions.should == [
          { 
            "ipProtocol"=>"tcp",
            "fromPort"=>22, 
            "toPort"=>22, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          }
        ]
      end
      it "should open a range of TCP ports" do
        ports = { ssh: (22..30) }
        @aws_provider.create_security_group("sg-range-name", "sg-range-desc", ports)
        created_sg = @fog_compute.security_groups.get("sg-range-name")
        created_sg.ip_permissions.should == [
          { 
            "ipProtocol"=>"tcp",
            "fromPort"=>22, 
            "toPort"=>30, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          }
        ]
      end
      it "should open a range of UDP ports" do
        ports = { ssh: { protocol: "udp", ports: (60000..600050) } }
        @aws_provider.create_security_group("sg-range-udp-name", "sg-range-udp-name", ports)
        created_sg = @fog_compute.security_groups.get("sg-range-udp-name")
        created_sg.ip_permissions.should == [
          { 
            "ipProtocol"=>"udp",
            "fromPort"=>60000, 
            "toPort"=>600050, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          }
        ]
      end
    end
  end
end
