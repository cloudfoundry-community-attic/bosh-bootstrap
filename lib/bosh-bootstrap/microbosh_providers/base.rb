require "bosh-bootstrap/microbosh_providers"
require "bcrypt"

class Bosh::Bootstrap::MicroboshProviders::Base
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

end
