# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "fog"
module Bosh; module Bootstrap; module Helpers; end; end; end

# A collection of methods related to getting fog_compute
# credentials for creating the inception VM
# and to provide to the MicroBOSH for its uses.
#
# Attempts to look in +settings.fog_path+ to see if there is a .fog file.
module Bosh::Bootstrap::Helpers::FogSetup
  
  # fog connection object to Compute tasks (VMs, IP addresses)
  def fog_compute
    @fog_compute ||= begin
      # Fog::Compute.new requires Hash with keys that are symbols
      # but Settings converts all keys to strings
      # So create a version of settings.fog_credentials with symbol keys
      credentials_with_symbols = settings.fog_credentials.inject({}) do |creds, key_pair|
        key, value = key_pair
        creds[key.to_sym] = value
        creds
      end
      Fog::Compute.new(credentials_with_symbols)
    end
  end

  def reset_fog_compute
    @fog_compute = nil
    @provider = nil # in cli.rb - I don't like this; need one wrapper for all CPI/compute calls
    # or don't create fog_compute until we know all IaaS details
  end

  def fog_config
    @fog_config ||= begin
      if File.exists?(fog_config_path)
        say "Found infrastructure API credentials at #{fog_config_path} (override with --fog)"
        YAML.load_file(fog_config_path)
      else
        say "No existing #{fog_config_path} fog configuration file", :yellow
        {}
      end
    end
  end

  def fog_config_path
    settings.fog_path
  end

end
