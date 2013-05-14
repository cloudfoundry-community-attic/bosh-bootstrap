module Bosh; module Bootstrap; module Cli; module Commands; end; end; end; end

require "cyoi/cli/provider"
require "bosh-bootstrap/cli/helpers"

# * select_provider
# * select_or_provision_public_networking # public_ip or ip/network/gateway
# * select_public_image_or_download_stemcell # download if stemcell
# * create_microbosh_manifest
# * microbosh_deploy
class Bosh::Bootstrap::Cli::Commands::Deploy
  include Bosh::Bootstrap::Cli::Helpers::Settings

  def initialize
    
  end

  def perform
    cyoi_provider = Cyoi::Cli::Provider.new([settings_dir])
    cyoi_provider.execute!
    reload_settings!
  end
end