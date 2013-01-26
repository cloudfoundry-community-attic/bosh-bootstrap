# Copyright (c) 2012-2013 Stark & Wayne, LLC

module Bosh; end

module Bosh::Providers
  extend self
  # returns a BOSH provider (CPI) specific object
  # with helpers related to that provider
  def for_bosh_provider_name(provider_name, fog_compute)
    case provider_name.to_sym
    when :aws
      require "bosh/providers/aws"
      Bosh::Providers::AWS.new(fog_compute)
    when :openstack
      require "bosh/providers/openstack"
      Bosh::Providers::OpenStack.new(fog_compute)
    else
      raise "please support #{provider_name} provider"
    end
  end
end
