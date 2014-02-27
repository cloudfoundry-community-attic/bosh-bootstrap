require "bosh-bootstrap/microbosh_providers"

# for the #sh helper
require "rake"
require "rake/file_utils"

class Bosh::Bootstrap::MicroboshProviders::Base
  include FileUtils

  attr_reader :manifest_path
  attr_reader :settings

  def initialize(manifest_path, settings)
    @manifest_path = manifest_path
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
     "logging"=>{"level"=>"DEBUG"}
    }
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

  def jenkins_bucket
    "bosh-jenkins-artifacts"
  end

  # downloads latest stemcell & returns path
  def download_stemcell
    mkdir_p(stemcell_dir)
    chdir(stemcell_dir) do
      stemcell_path = File.expand_path(File.basename(stemcell_uri))
      unless File.exists?(stemcell_path)
        sh "curl -O '#{stemcell_uri}'"
      end
      return stemcell_path
    end
  end

  def stemcell_dir
    File.dirname(manifest_path)
  end
end
