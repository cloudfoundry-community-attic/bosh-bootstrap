module Bosh::Bootstrap::NetworkProviders
  class Dummy
    def initialize(provider_client)
    end

    def perform
    end
  end
end
Bosh::Bootstrap::NetworkProviders.register_provider("dummy", Bosh::Bootstrap::NetworkProviders::Dummy)
