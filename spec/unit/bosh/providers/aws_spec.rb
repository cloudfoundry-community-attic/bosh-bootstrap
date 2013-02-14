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
      @aws_provider = Bosh::Providers.for_bosh_provider_name("aws", @fog_compute)
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
      it "should open not open ports if they are already open" do
        @aws_provider.create_security_group("sg2", "", { ssh: { protocol: "udp", ports: (60000..600050) } })
        @aws_provider.create_security_group("sg2", "", { ssh: { protocol: "udp", ports: (60010..600040) } })
        @aws_provider.create_security_group("sg2", "", { ssh: { protocol: "udp", ports: (60000..600050) } })
        created_sg = @fog_compute.security_groups.get("sg2")
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
      it "should open ports even if they are already open for a different protocol" do
        @aws_provider.create_security_group("sg3", "", { ssh: { protocol: "udp", ports: (60000..600050) } })
        @aws_provider.create_security_group("sg3", "", { ssh: { protocol: "tcp", ports: (60000..600050) } })
        created_sg = @fog_compute.security_groups.get("sg3")
        created_sg.ip_permissions.should == [
          { 
            "ipProtocol"=>"udp",
            "fromPort"=>60000, 
            "toPort"=>600050, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          },
          { 
            "ipProtocol"=>"tcp",
            "fromPort"=>60000, 
            "toPort"=>600050, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          }
        ]
      end
      it "should open ports even if they are already open for a different ip_range" do
        default_ports = {
           all_internal_tcp: { protocol: "tcp", ip_range: "1.1.1.1/32", ports: (0..65535) }
        }
        @aws_provider.create_security_group("sg6", "sg6", default_ports)
        @aws_provider.create_security_group("sg6", "sg6", { mosh: { protocol: "tcp", ports: (15..30) } })
        created_sg = @fog_compute.security_groups.get("sg6")
        created_sg.ip_permissions.should == [
          { 
            "ipProtocol"=>"tcp",
            "fromPort"=>0, 
            "toPort"=>65535, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"1.1.1.1/32" } ] 
          },
          { 
            "ipProtocol"=>"tcp",
            "fromPort"=>15, 
            "toPort"=>30, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          }
        ]
      end
      it "should open ports on the default sg" do
        @aws_provider.create_security_group("default", "default", { mosh: { protocol: "tcp", ports: (15..30) } })
        created_sg = @fog_compute.security_groups.get("default")
        expected_rule = { 
            "ipProtocol"=>"tcp",
            "fromPort"=>15, 
            "toPort"=>30, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          }
        created_sg.ip_permissions.should include expected_rule
      end
      #AWS allows overlapping port ranges, and it makes it easier to see the separate "rules" that were added
      it "should create overlapping port ranges" do
        @aws_provider.create_security_group("sg4", "", { ssh: { protocol: "udp", ports: (10..20) } })
        @aws_provider.create_security_group("sg4", "", { ssh: { protocol: "udp", ports: (15..30) } })
        created_sg = @fog_compute.security_groups.get("sg4")
        created_sg.ip_permissions.should == [
          { 
            "ipProtocol"=>"udp",
            "fromPort"=>10, 
            "toPort"=>20, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          },
          { 
            "ipProtocol"=>"udp",
            "fromPort"=>15, 
            "toPort"=>30, 
            "groups"=>[], 
            "ipRanges"=>[ { "cidrIp"=>"0.0.0.0/0" } ] 
          }
        ]
      end
    end
  end
end
