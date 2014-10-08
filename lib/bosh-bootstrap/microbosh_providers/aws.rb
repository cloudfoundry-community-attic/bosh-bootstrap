require "bosh-bootstrap/microbosh_providers/base"

module Bosh::Bootstrap::MicroboshProviders
  class AWS < Base

    def to_hash
      data = super.merge({
      "network"=>network_configuration,
       "resources"=>
        {"persistent_disk"=>persistent_disk,
         "cloud_properties"=>resources_cloud_properties},
       "cloud"=>
        {"plugin"=>"aws",
         "properties"=>
          {"aws"=>cloud_properties}},
       "apply_spec"=>
        {"agent"=>
          {"blobstore"=>{"address"=>public_ip},
           "nats"=>{"address"=>public_ip}},
         "properties"=>{"aws_registry"=>{"address"=>public_ip}}}})
      if az = settings.exists?("provider.az")
        data["resources"]["cloud_properties"]["availability_zone"] = az
      end
      data
    end

    def network_configuration
      if vpc?
        {
          "type" =>"manual",
          "ip"   => public_ip,
          "dns"  => [vpc_dns(public_ip)],
          "cloud_properties" => {
            "subnet" => settings.address.subnet_id
          }
        }

      else
        {
          "type"=>"dynamic",
          "vip"=>public_ip
        }
      end
    end

    def persistent_disk
      settings.bosh.persistent_disk
    end

    def resources_cloud_properties
      {"instance_type"=>"m3.medium"}
    end

    def cloud_properties
      {"access_key_id"=>settings.provider.credentials.aws_access_key_id,
       "secret_access_key"=>settings.provider.credentials.aws_secret_access_key,
       "region"=>settings.provider.region,
       "ec2_endpoint"=>"ec2.#{settings.provider.region}.amazonaws.com",
       "default_security_groups"=>security_groups,
       "default_key_name"=>microbosh_name,
       "ec2_private_key"=>private_key_path}
    end

    def security_groups
      ["ssh",
       "dns_server",
       "bosh"]
    end

    def aws_region
      settings.provider.region
    end

    # @return Bosh::Cli::PublicStemcell latest stemcell for aws/trusty
    # If us-east-1 region, then return light stemcell
    def latest_stemcell
      @latest_stemcell ||= begin
        trusty_stemcells = if light_stemcell?
          recent_stemcells.select do |s|
            s.name =~ /aws/ && s.name =~ /trusty/ && s.name =~ /^light/
          end
        else
          recent_stemcells.select do |s|
            s.name =~ /aws/ && s.name =~ /trusty/ && s.name =~ /^bosh/
          end
        end
        trusty_stemcells.sort {|s1, s2| s2.version <=> s1.version}.first
      end
    end

    # only us-east-1 has light stemcells published
    def light_stemcell?
      aws_region == "us-east-1"
    end

    def vpc?
      settings.address["subnet_id"]
    end

    def vpc_dns(ip_address)
      ip_address.gsub(/^(\d+)\.(\d+)\..*/, '\1.\2.0.2')
    end
  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("aws", Bosh::Bootstrap::MicroboshProviders::AWS)
