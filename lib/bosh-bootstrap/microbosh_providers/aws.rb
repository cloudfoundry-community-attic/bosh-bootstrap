require "bosh-bootstrap/microbosh_providers"

class Bosh::Bootstrap::MicroboshProviders::AWS
  include FileUtils

  attr_reader :path
  attr_reader :settings

  def initialize(path)
    @path = path
  end

  def create_microbosh_yml(settings)
    @settings = settings.is_a?(Hash) ? Settingslogic.new(settings) : settings
    raise "@settings must be Settingslogic (or Hash)" unless @settings.is_a?(Settingslogic)
    mkdir_p(File.dirname(path))
    File.open(path, "w") do |f|
      f << self.to_hash.to_yaml
    end
  end

  def to_hash
    {"name"=>microbosh_name,
     "env"=>{"bosh"=>{"password"=>salted_password}},
     "logging"=>{"level"=>"DEBUG"},
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
       "properties"=>{"aws_registry"=>{"address"=>public_ip}}}}
  end

  def microbosh_name
    "test-bosh"
  end

  def salted_password
    "salted_password"
  end

  def public_ip
    "$MICROBOSH_IP$"
  end

  def persistent_disk
    16384
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
end

Bosh::Bootstrap::MicroboshProviders.register_provider("aws", Bosh::Bootstrap::MicroboshProviders::AWS)