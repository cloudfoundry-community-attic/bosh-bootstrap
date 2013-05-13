require "bosh-bootstrap/microbosh_providers"

class Bosh::Bootstrap::MicroboshProviders::AWS
  include FileUtils

  attr_reader :path

  def initialize(path)
    @path = path
  end

  def create_microbosh_yml(settings)
    mkdir_p(File.dirname(path))
    File.open(path, "w") do |f|
      f << self.to_hash.to_yaml
    end
  end

  def to_hash
    {}
  end
end

Bosh::Bootstrap::MicroboshProviders.register_provider("aws", Bosh::Bootstrap::MicroboshProviders::AWS)