module Bosh; module Bootstrap; module Cli; module Commands; end; end; end; end

require "cyoi/cli/provider"
require "cyoi/cli/address"
require "bosh-bootstrap/cli/helpers"

class Bosh::Bootstrap::Cli::Commands::Deploy
  include Bosh::Bootstrap::Cli::Helpers::Settings

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
    create_microbosh_manifest
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

  # download if stemcell
  def select_public_image_or_download_stemcell
    
  end

  def create_microbosh_manifest
  
  end

  def perform_microbosh_deploy
    
  end
end