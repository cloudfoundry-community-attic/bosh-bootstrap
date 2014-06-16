module Bosh::Bootstrap::NetworkProviders
  class AWS
    attr_reader :cyoi_provider_client

    def initialize(cyoi_provider_client)
      @cyoi_provider_client = cyoi_provider_client
    end

    def perform
      security_groups.each do |name, ports|
        cyoi_provider_client.create_security_group(name.to_s, name.to_s, ports: ports)
      end
    end

    protected
    def security_groups
      {
        ssh: 22,
        dns_server: { protocol: "udp", ports: (53..53) },
        bosh: [4222, 6868, 25250, 25555, 25777]
      }
    end
  end
end
Bosh::Bootstrap::NetworkProviders.register_provider("aws", Bosh::Bootstrap::NetworkProviders::AWS)
