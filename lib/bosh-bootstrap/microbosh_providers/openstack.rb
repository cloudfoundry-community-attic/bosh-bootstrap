require "bosh-bootstrap/microbosh_providers/base"

module Bosh::Bootstrap::MicroboshProviders
  class OpenStack < Base
    def to_hash
      super.merge({
       "network"=>network_configuration,
       "resources"=>
        {"persistent_disk"=>persistent_disk,
         "cloud_properties"=>resources_cloud_properties},
       "cloud"=>
        {"plugin"=>"openstack",
         "properties"=>
          {"openstack"=>cloud_properties}},
      })
    end

    def public_ip
      settings.bosh.public_ip
    end

    def persistent_disk
      settings.bosh.persistent_disk
    end

    def resources_cloud_properties
      {"instance_type"=>"m1.medium"}
    end

    # network:
    #   name: default
    #   type: dynamic
    #   label: private
    #   ip: 1.2.3.4
    def network_configuration
      {"name"=>"default",
        "type"=>"dynamic",
        "label"=>"private",
        "ip"=>public_ip
      }
    end

    def cloud_properties
      {
        "auth_url"=>settings.provider.credentials.openstack_auth_url,
        "username"=>settings.provider.credentials.openstack_username,
        "api_key"=> settings.provider.credentials.openstack_api_key,
        "tenant"=>  settings.provider.credentials.openstack_tenant,
        "default_security_groups"=>security_groups,
        "default_key_name"=>microbosh_name,
        "private_key"=>private_key_path}
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
  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("openstack", Bosh::Bootstrap::MicroboshProviders::OpenStack)
