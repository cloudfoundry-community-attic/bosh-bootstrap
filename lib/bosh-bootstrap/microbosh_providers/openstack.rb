require "bosh-bootstrap/microbosh_providers/base"

module Bosh::Bootstrap::MicroboshProviders
  class OpenStack < Base

    def to_hash
      data = super.deep_merge({
       "network"=>network_configuration,
       "resources"=>
        {"persistent_disk"=>persistent_disk,
         "cloud_properties"=>resources_cloud_properties},
       "cloud"=>
        {"plugin"=>"openstack",
         "properties"=>
          {"openstack"=>cloud_properties}},
       "apply_spec"=>
        {"agent"=>
          {"blobstore"=>{"address"=>public_ip},
           "nats"=>{"address"=>public_ip}},
         "properties"=>
           {"director"=>
             {"max_threads"=>3},
            "hm"=>{"resurrector_enabled" => true}}}
      })
      if proxy?
        data["apply_spec"]["properties"]["director"]["env"] = proxy
      end
      data
    end

    # For Nova/Floating IP:
    #   network:
    #     type: dynamic
    #     vip: 1.2.3.4
    # For Neutron/Floating IP:
    #   network:
    #     type: dynamic
    #     vip: 1.2.3.4  # public floating IP
    #     cloud_properties:
    #       net_id: XXX # internal subnet
    # For Neutron/Internal IP:
    #   network:
    #     type: manual
    #     vip: 10.10.10.3 # an IP in subnets range
    #     cloud_properties:
    #       net_id: XXX   # internal subnet
    def network_configuration
      if nova?
        {
          "type"=>"dynamic",
          "vip"=>public_ip
        }
      elsif neutron? && using_external_gateway?
        {
          "type"=>"dynamic",
          "vip"=>public_ip,
          "cloud_properties" => {
            "net_id" => settings.address.subnet_id
          }
        }
      else
        {
          "type"=>"manual",
          "ip"=>public_ip,
          "cloud_properties" => {
            "net_id" => settings.address.subnet_id
          }
        }
      end
    end

    def nova?
      !neutron?
    end

    def neutron?
      settings.exists?("address.subnet_id")
    end

    def using_external_gateway?
      settings.exists?("address.pool_name")
    end

    def persistent_disk
      settings.bosh.persistent_disk
    end

    # TODO Allow discovery of an appropriate OpenStack flavor with 2+CPUs, 3+G RAM
    def resources_cloud_properties
      {"instance_type"=>"m1.medium"}
    end

    def provider_state_timeout
      settings.exists?("provider") && settings.provider.exists?("state_timeout") ? settings.provider.state_timeout : 300
    end

    def cloud_properties
      {
        "auth_url"=>settings.provider.credentials.openstack_auth_url,
        "username"=>settings.provider.credentials.openstack_username,
        "api_key"=>settings.provider.credentials.openstack_api_key,
        "tenant"=>settings.provider.credentials.openstack_tenant,
        "region"=>region,
        "default_security_groups"=>security_groups,
        "default_key_name"=>microbosh_name,
        "state_timeout"=>provider_state_timeout,
        "private_key"=>private_key_path,
        # TODO: Only ignore SSL verification if requested by user
        "connection_options"=>{
          "ssl_verify_peer"=>false
        },
        "boot_from_volume"=>boot_from_volume}
    end

    def region
      if settings.provider.credentials.openstack_region && !settings.provider.credentials.openstack_region.empty?
       return settings.provider.credentials.openstack_region
      end
      nil
    end

    def security_groups
      ["ssh",
       "dns-server",
       "bosh"]
    end

    def boot_from_volume
      !!(settings.provider["options"] && settings.provider.options.boot_from_volume)
    end

    # @return Bosh::Cli::PublicStemcell latest stemcell for openstack/trusty
    def latest_stemcell
      @latest_stemcell ||= begin
        trusty_stemcells = recent_stemcells.select do |s|
          s.name =~ /openstack/ && s.name =~ /trusty/
        end
        trusty_stemcells.sort {|s1, s2| s2.version <=> s1.version}.first
      end
    end

    def owned_images
      fog_compute.images
    end

    # @return [String] Any AMI imageID
    # e.g. "BOSH-14c85f35-3dd3-4200-af85-ada65216b2de" for given BOSH stemcell name/version
    # Usage: find_ami_for_stemcell("bosh-openstack-kvm-ubuntu-trusty-go_agent", "2732")
    def find_image_for_stemcell(name, version)
      image = owned_images.find do |image|
        metadata = image.metadata
        metadata_name = metadata.find { |m| m.key == "name" }
        metadata_version = metadata.find { |m| m.key == "version" }
        metadata_name && metadata_version && metadata_name.value == name && metadata_version.value == version
      end
      image.name if image
    end

    def discover_if_stemcell_image_already_uploaded
      find_image_for_stemcell(latest_stemcell.stemcell_name, latest_stemcell.version)
    end
  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("openstack", Bosh::Bootstrap::MicroboshProviders::OpenStack)
