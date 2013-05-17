module Bosh::Bootstrap::NetworkProviders
  extend self
  def register_provider(provider_name, provider_klass)
    @providers ||= {}
    @providers[provider_name] = provider_klass
  end

  def provider_class(provider_name)
    @providers[provider_name]
  end
end
