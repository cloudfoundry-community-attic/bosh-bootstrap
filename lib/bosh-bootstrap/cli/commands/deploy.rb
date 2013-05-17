module Bosh; module Bootstrap; module Cli; module Commands; end; end; end; end

require "cyoi/cli/provider"
require "cyoi/cli/address"
require "bosh-bootstrap/cli/helpers"
require "bosh-bootstrap/microbosh"

class Bosh::Bootstrap::Cli::Commands::Deploy
  include Bosh::Bootstrap::Cli::Helpers

  def initialize
    
  end

  # * select_provider
  # * select_or_provision_public_networking # public_ip or ip/network/gateway
  # * select_public_image_or_download_stemcell # download if stemcell
  # * create_microbosh_manifest
  # * microbosh_deploy
  def perform
    select_provider
    select_or_provision_public_networking
    select_public_image_or_download_stemcell
    perform_microbosh_deploy
  end

  protected
  def select_provider
    provider = Cyoi::Cli::Provider.new([settings_dir])
    provider.execute!
    reload_settings!
  end

  # public_ip or ip/network/gateway
  def select_or_provision_public_networking
    # TODO remove this when off the airplane
    require "fog"
    Fog.mock!

    address = Cyoi::Cli::Address.new([settings_dir])
    address.execute!
    reload_settings!
  end

  def microbosh_provider
    @microbosh_provider ||= begin
      provider_name = settings.provider.name
      require "bosh-bootstrap/microbosh_providers/#{provider_name}"
      klass = Bosh::Bootstrap::MicroboshProviders.provider_class(provider_name)
      klass.new(File.join(settings_dir, "deployments/micro_bosh.yml"))
    end
  end

  # download if stemcell
  def select_public_image_or_download_stemcell
    settings.set("bosh.stemcell", microbosh_provider.stemcell)
    save_settings!
  end

  def perform_microbosh_deploy
    @microbosh ||= Bosh::Bootstrap::Microbosh.new(settings_dir)
    @microbosh.deploy(settings.provider.name, settings)
  end
end