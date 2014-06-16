require "bosh-bootstrap/network_providers"
require "bosh-bootstrap/network_providers/dummy"

class Bosh::Bootstrap::Network

  attr_reader :provider_name
  attr_reader :cyoi_provider_client

  def initialize(provider_name, cyoi_provider_client)
    @provider_name = provider_name
    @cyoi_provider_client = cyoi_provider_client
  end

  def deploy
    network_provider.perform
  end

  # Attempt to load and instantiate a NetworkProviders class
  # Else return NetworkProviders::Dummy which does nothing
  def network_provider
    @network_provider ||= begin
      begin
        require "bosh-bootstrap/network_providers/#{provider_name}"
        klass = Bosh::Bootstrap::NetworkProviders.provider_class(provider_name)
      rescue LoadError
        klass = Bosh::Bootstrap::NetworkProviders.provider_class("dummy")
      end
      klass.new(cyoi_provider_client)
    end
  end

end
