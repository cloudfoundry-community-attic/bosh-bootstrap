require "bosh-bootstrap/microbosh_providers"
require "bosh-bootstrap/public_stemcells"

# for the #sh helper
require "rake"
require "rake/file_utils"

class Bosh::Bootstrap::MicroboshProviders::Base
  include FileUtils

  attr_reader :manifest_path
  attr_reader :settings
  attr_reader :fog_compute

  def initialize(manifest_path, settings, fog_compute)
    @manifest_path = manifest_path
    @fog_compute = fog_compute
    @settings = settings.is_a?(Hash) ? ReadWriteSettings.new(settings) : settings
    raise "@settings must be ReadWriteSettings (or Hash)" unless @settings.is_a?(ReadWriteSettings)
  end

  def create_microbosh_yml(settings)
    @settings = settings.is_a?(Hash) ? ReadWriteSettings.new(settings) : settings
    raise "@settings must be ReadWriteSettings (or Hash)" unless @settings.is_a?(ReadWriteSettings)
    mkdir_p(File.dirname(manifest_path))
    File.open(manifest_path, "w") do |f|
      f << self.to_hash.to_yaml
    end
  end

  def to_hash
    {"name"=>microbosh_name,
     "logging"=>{"level"=>"DEBUG"},
    }.merge(default_apply_spec)
  end

  def microbosh_name
    settings.bosh.name
  end

  def salted_password
    # BCrypt::Password.create(settings.bosh.password).to_s.force_encoding("UTF-8")
    settings.bosh.salted_password
  end

  def public_ip
    settings.address.ip
  end

  def public_ip?
    settings.exists?("address.ip")
  end

  def private_key_path
    settings.key_pair.path
  end

  def proxy
    settings.proxy.to_hash
  end

  def proxy?
    settings.exists?("proxy")
  end

  def jenkins_bucket
    "bosh-jenkins-artifacts"
  end

  def stemcell_path
    settings.exists?("bosh.stemcell_path") || begin
      if image = discover_if_stemcell_image_already_uploaded
        return image
      end
      download_stemcell
    end
  end

  def recent_stemcells
    @recent_stemcells ||= begin
      public_stemcells = Bosh::Bootstrap::PublicStemcells.new
      public_stemcells.recent
    end
  end

  # override if infrastructure has enough information to
  # discover if stemcell already uploaded and can be used
  # via its image ID/AMI
  def discover_if_stemcell_image_already_uploaded
  end

  # downloads latest stemcell & returns path
  def download_stemcell
    mkdir_p(stemcell_dir)
    chdir(stemcell_dir) do
      path = File.expand_path(latest_stemcell.name)
      unless File.exists?(path)
        sh "curl -O '#{latest_stemcell.url}'"
      end
      return path
    end
  end

  def stemcell_dir
    File.dirname(manifest_path)
  end

  def default_apply_spec
    return {} unless  settings.exists?("recursor")
    {"apply_spec"=>
      {"properties"=>
       {"dns"=>{
         "recursor"=>settings.recursor} }
      }
    }
  end
end
