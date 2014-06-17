module Bosh; module Bootstrap; module Cli; module Commands; end; end; end; end

require "cyoi/cli/provider"
require "cyoi/cli/address"
require "bosh-bootstrap/cli/helpers"
require "bosh-bootstrap/microbosh"

class Bosh::Bootstrap::Cli::Commands::Deploy
  include Bosh::Bootstrap::Cli::Helpers

  # * select_provider
  # * select_or_provision_public_networking # public_ip or ip/network/gateway
  # * select_public_image_or_download_stemcell # download if stemcell
  # * create_microbosh_manifest
  # * microbosh_deploy
  def perform
    settings.set_default("bosh.name", "firstbosh")
    save_settings!

    select_provider
    select_or_provision_public_networking
    setup_keypair
    select_public_image_or_download_stemcell
    perform_microbosh_deploy
  end

  protected
  def select_provider
    provider = Cyoi::Cli::Provider.new([settings_dir])
    provider.execute!
    reload_settings!
  end

  def cyoi_provider_client
    @provider_client ||= Cyoi::Providers.provider_client(settings.provider)
  end

  # public_ip or ip/network/gateway
  def select_or_provision_public_networking
    address = Cyoi::Cli::Address.new([settings_dir])
    address.execute!
    reload_settings!

    # TODO why passing provider_client rather than a Cyoi::Cli::Network object?
    network = Bosh::Bootstrap::Network.new(settings.provider.name, cyoi_provider_client)
    network.deploy
  end

  # TODO should this go inside Microbosh, like NetworkProvider is to Network?
  def microbosh_provider
    @microbosh_provider ||= begin
      provider_name = settings.provider.name
      require "bosh-bootstrap/microbosh_providers/#{provider_name}"
      klass = Bosh::Bootstrap::MicroboshProviders.provider_class(provider_name)
      klass.new(File.join(settings_dir, "deployments/#{settings.bosh.name}/micro_bosh.yml"), settings)
    end
  end

  # download if stemcell
  def select_public_image_or_download_stemcell
    print "Determining stemcell image/file to use... "
    stemcell = microbosh_provider.stemcell
    while (stemcell || "").size == 0
      puts "failed. Retrying..."
      print "Determining stemcell image/file to use... "
      stemcell = microbosh_provider.stemcell
    end
    settings.set("bosh.stemcell", stemcell)
    puts settings.bosh.stemcell
  end

  def perform_microbosh_deploy
    settings.set("bosh.persistent_disk", 16 * 1024)
    @microbosh ||= Bosh::Bootstrap::Microbosh.new(settings_dir, microbosh_provider)
    @microbosh.deploy(settings)
  end
end
