module Bosh::Bootstrap::NetworkProviders
  class Dummy
    def initialize(cyoi_provider_client)
    end

    def perform(settings)
    end
  end
end
Bosh::Bootstrap::NetworkProviders.register_provider("dummy", Bosh::Bootstrap::NetworkProviders::Dummy)
