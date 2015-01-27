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
          "properties"=>
            {"aws_registry"=>{"address"=>public_ip},
            "hm"=>{"resurrector_enabled" => true}}},
      })
      if az = settings.exists?("provider.az")
        data["resources"]["cloud_properties"]["availability_zone"] = az
      end
      if vpc?
        dns = settings.exists?("recursor") ? settings.recursor : vpc_dns(public_ip)
        data["apply_spec"]["properties"]["dns"] = {}
        data["apply_spec"]["properties"]["dns"]["recursor"] = dns
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
      sg_suffix=""
      if vpc?
        sg_suffix="-#{settings.address.vpc_id}"
      end
      [
        "ssh#{sg_suffix}",
        "dns-server#{sg_suffix}",
        "bosh#{sg_suffix}"
      ]
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
    # Note: this should work for all /16 vpcs and may run into issues with other blocks
    def vpc_dns(ip_address)
      ip_address.gsub(/^(\d+)\.(\d+)\..*/, '\1.\2.0.2')
    end

    # @return [Hash] description of each self-owned AMI
    # {"blockDeviceMapping"=>
    #  [{"deviceName"=>"/dev/sda",
    #    "snapshotId"=>"snap-56c7089e",
    #    "volumeSize"=>2,
    #    "deleteOnTermination"=>"true"},
    #   {"deviceName"=>"/dev/sdb", "virtualName"=>"ephemeral0"}],
    # "productCodes"=>[],
    # "stateReason"=>{},
    # "tagSet"=>{"Name"=>"bosh-aws-xen-ubuntu-trusty-go_agent 2732"},
    # "imageId"=>"ami-c19ed3f1",
    # "imageLocation"=>"357913607455/BOSH-64a71269-18a2-450b-9e61-713ed70fa62a",
    # "imageState"=>"available",
    # "imageOwnerId"=>"357913607455",
    # "isPublic"=>false,
    # "architecture"=>"x86_64",
    # "imageType"=>"machine",
    # "kernelId"=>"aki-94e26fa4",
    # "name"=>"BOSH-64a71269-18a2-450b-9e61-713ed70fa62a",
    # "description"=>"bosh-aws-xen-ubuntu-trusty-go_agent 2732",
    # "rootDeviceType"=>"ebs",
    # "rootDeviceName"=>"/dev/sda1",
    # "virtualizationType"=>"paravirtual",
    # "hypervisor"=>"xen"}
    def owned_images
      my_images_raw = fog_compute.describe_images('Owner' => 'self')
      my_images_raw.body["imagesSet"]
    end

    # @return [String] Any AMI imageID, e.g. "ami-c19ed3f1" for given BOSH stemcell name/version
    # Usage: find_ami_for_stemcell("bosh-aws-xen-ubuntu-trusty-go_agent", "2732")
    def find_ami_for_stemcell(name, version)
      image = owned_images.find do |image|
        image["description"] == "#{name} #{version}"
      end
      image["imageId"] if image
    end

    def discover_if_stemcell_image_already_uploaded
      find_ami_for_stemcell(latest_stemcell.stemcell_name, latest_stemcell.version)
    end
  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("aws", Bosh::Bootstrap::MicroboshProviders::AWS)
