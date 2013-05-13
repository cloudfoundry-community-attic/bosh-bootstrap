class Bosh::Bootstrap::Microbosh
  include FileUtils

  attr_reader :base_path
  attr_reader :stemcell
  attr_reader :provider

  def initialize(base_path, stemcell)
    @base_path = base_path
    @stemcell = stemcell
  end

  def deploy(provider_name, settings)
    mkdir_p(base_path)
    chdir(base_path) do
      setup_base_path
      initialize_microbosh_provider(provider_name)
      create_microbosh_yml(settings)
      deploy_or_update
    end
  end

  protected
  def setup_base_path
    gempath = File.expand_path("../../..", __FILE__)
    File.open("Gemfile", "w") do |f|
      f << <<-RUBY
source 'https://rubygems.org'
source 'https://s3.amazonaws.com/bosh-jenkins-gems/'

gem "bosh-bootstrap", path: #{gempath}
      RUBY
    end
    rm_rf "Gemfile.lock"
    sh "bundle install"
  end

  def initialize_microbosh_provider(provider_name)
    @provider ||= begin
      require "bosh-bootstrap/microbosh_providers/#{provider_name}"
      klass = Bosh::Bootstrap::MicroboshProviders.provider_class(provider_name)
      klass.new(File.expand_path("deployments/micro_bosh.yml"))
    end
  end

  def create_microbosh_yml(settings)
    provider.create_microbosh_yml(settings)
  end

  def deploy_or_update
      sh "bundle exec bosh micro deploy #{stemcell}"
  end
end