# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "settingslogic"
module Bosh; module Bootstrap; module Helpers; end; end; end

# Helper methods for loading/saving settings
module Bosh::Bootstrap::Helpers::Settings
  # Previously selected settings are stored in a YAML manifest
  # Protects the manifest file with user-only priveleges
  def settings
    @settings ||= begin
      FileUtils.mkdir_p(File.dirname(settings_path))
      unless File.exists?(settings_path)
        File.open(settings_path, "w") do |file|
          file << {}.to_yaml
        end
      end
      FileUtils.chmod 0600, settings_path
      Settingslogic.new(settings_path)
    end
  end

  def save_settings!
    File.open(settings_path, "w") do |file|
      raw_settings_yaml = settings.to_yaml.gsub(" !ruby/hash:Settingslogic", "")
      file << raw_settings_yaml
    end
    @settings = nil # force to reload & recreate helper methods
  end

  def settings_path
    manifest_path = ENV["MANIFEST"] || "~/.bosh_bootstrap/manifest.yml"
    File.expand_path(manifest_path)
  end

end
