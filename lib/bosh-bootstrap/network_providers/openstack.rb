module Bosh::Bootstrap::NetworkProviders
  class OpenStack
    attr_reader :provider_client

    def initialize(provider_client)
      @provider_client = provider_client
    end

    def perform
      security_groups.each do |name, ports|
        provider_client.create_security_group(name.to_s, name.to_s, ports: ports)
      end
    end

    protected
    def security_groups
      {
        ssh: 22,
        bosh_nats_server: 4222,
        bosh_blobstore: 25250,
        bosh_director: 25555,
        bosh_registry: 25777
      }
    end
  end
end
Bosh::Bootstrap::NetworkProviders.register_provider("openstack", Bosh::Bootstrap::NetworkProviders::OpenStack)
