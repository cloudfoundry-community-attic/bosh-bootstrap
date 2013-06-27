require "bosh-bootstrap/microbosh_providers/base"

module Bosh::Bootstrap::MicroboshProviders
  class AWS < Base
    # if us-east-1 -> ami
    # if not running in target aws region -> error "Must either use us-east-1 or run 'bosh bootstrap deploy' within target AWS region"
    # else download stemcell & return path
    def stemcell
      unless settings.exists?("bosh.stemcell")
        if ami_region?
          fetch_ami
        else
          download_stemcell
        end
      end
    end

    def to_hash
      data = super.merge({
       "network"=>{"type"=>"dynamic", "vip"=>public_ip},
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

    def persistent_disk
      settings.bosh.persistent_disk
    end

    def resources_cloud_properties
      {"instance_type"=>"m1.medium"}
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
       "bosh_agent_https",
       "bosh_nats_server",
       "bosh_blobstore",
       "bosh_director",
       "bosh_registry"]
    end

    def aws_region
      settings.provider.region
    end

    # only us-east-1 has AMIs published currently
    def ami_region?
      aws_region == "us-east-1"
    end

    def fetch_ami
      Net::HTTP.get("#{jenkins_bucket}.s3.amazonaws.com", ami_uri_path(aws_region)).strip
    end

    def ami_uri_path(region)
      "/last_successful_micro-bosh-stemcell-aws_ami_#{region}"
    end

    def stemcell_uri
      "http://#{jenkins_bucket}.s3.amazonaws.com/micro-bosh-stemcell/aws/latest-micro-bosh-stemcell-aws.tgz"
    end
  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("aws", Bosh::Bootstrap::MicroboshProviders::AWS)
