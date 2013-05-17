require "bosh-bootstrap/microbosh_providers/base"

module Bosh::Bootstrap::MicroboshProviders
  class AWS < Base
    def to_hash
      super.merge({
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
       "bosh_agent_http",
       "bosh_nats_server",
       "bosh_blobstore",
       "bosh_director",
       "bosh_registry"]
    end

    def private_key_path
      "/home/vcap/microboshes/aws-us-west-2/ssh/#{microbosh_name}.pem"
    end

    # if us-east-1 -> ami
    # if not running in target aws region -> error "Must either use us-east-1 or run 'bosh bootstrap deploy' within target AWS region"
    # else download stemcell & return path
    def stemcell
      "ami-123456"
    end
  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("aws", Bosh::Bootstrap::MicroboshProviders::AWS)
