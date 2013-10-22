require "bosh-bootstrap/microbosh_providers"
require "bosh-bootstrap/cli/helpers"

# Configures and deploys (or re-deploys) a micro bosh.
# A "micro bosh" is a single VM containing all necessary parts of bosh
# and is deployed from the terminal; rather than from another bosh.
#
# Usage:
#   microbosh = Bosh::Bootstrap::Microbosh.new(project_path)
#   settings = ReadWriteSettings.new({
#     "provider" => {"name" => "aws", "credentials" => {...}},
#     "address" => {"ip" => "1.2.3.4"},
#     "bosh" => {
#       "name" => "test-bosh",
#       "stemcell" => "ami-123456",
#       "salted_password" => "452435hjg2345hjg2435ghk3452"
#     }
#   })
#   microbosh.deploy("aws", settings)
class Bosh::Bootstrap::Microbosh
  include FileUtils
  include Bosh::Bootstrap::Cli::Helpers::Bundle

  attr_reader :base_path
  attr_reader :provider
  attr_reader :bosh_name
  attr_reader :deployments_dir
  attr_reader :manifest_yml

  def initialize(base_path, provider)
    @base_path = base_path
    @provider = provider
  end

  def deploy(settings)
    @bosh_name = settings.bosh.name
    @deployments_dir = File.join(base_path, "deployments")
    @manifest_yml = File.join(deployments_dir, bosh_name, "micro_bosh.yml")
    mkdir_p(File.dirname(manifest_yml))
    chdir(base_path) do
      setup_base_path
      setup_gems
      create_microbosh_yml(settings)
      deploy_or_update(settings.bosh.name, settings.bosh.stemcell)
    end
  end

  protected
  def setup_base_path
    system 'which git'
      if $?.to_i!=0
          puts "Git doesn't seem to be on your path.  Maybe it's not installed?"
          exit 1
      end
    sh("git init")
    sh("git add .")
    sh("git commit -m 'Creating repo to suppress bundler warnings'")
  end

  def setup_gems
    gempath = File.expand_path("../../..", __FILE__)
    pwd = File.expand_path(".")
    File.open("Gemfile", "w") do |f|
      f << <<-RUBY
source 'https://rubygems.org'

gem "bosh-bootstrap", path: "#{gempath}"
gem "bosh_cli_plugin_micro"
      RUBY
    end
    rm_rf "Gemfile.lock"
    bundle "install"
  end

  def create_microbosh_yml(settings)
    provider.create_microbosh_yml(settings)
  end

  def deploy_or_update(bosh_name, stemcell)
    chdir("deployments") do
      bundle "exec bosh micro deployment", bosh_name
      bundle "exec bosh -n micro deploy", stemcell
    end
  end
end