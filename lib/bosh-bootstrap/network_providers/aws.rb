module Bosh::Bootstrap::NetworkProviders
  class AWS
    attr_reader :provider_client

    def initialize(provider_client)
      @provider_client = provider_client
    end

    def perform
      provider_client.create_security_group("dns_server", "dns_server", ports: { protocol: "udp", ports: (53..53) })
      provider_client.create_security_group("bosh", "bosh", ports: {
        ssh: 22,
        nats: 4222,
        agent: 6868,
        blobstore: 25250,
        director: 25555,
        registry: 25777
      })

      # security_groups.each do |name, ports|
      #   provider_client.create_security_group(name.to_s, name.to_s, ports: ports)
      # end
    end

    protected
    # def security_groups
    #   {
    #     dns_server: { protocol: "udp", ports: (53..53) },
    #     bosh: 
    #   }
    # end
  end
end
Bosh::Bootstrap::NetworkProviders.register_provider("aws", Bosh::Bootstrap::NetworkProviders::AWS)
