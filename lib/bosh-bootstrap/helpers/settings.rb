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

  # the base directory for holding the manifest settings file
  # and private keys
  #
  # Defaults to ~/.bosh_bootstrap; and can be overridden with either:
  # * $SETTINGS - to a folder (supported method)
  # * $MANIFEST - to a folder (unsupported)
  # * $MANIFEST - to a specific file; but uses its parent dir (unsupported, backwards compatibility)
  def settings_dir
    @settings_dir ||= begin
      settings_dir = ENV["SETTINGS"] if ENV["SETTINGS"]
      settings_dir ||= ENV["MANIFEST"] if ENV["MANIFEST"]
      settings_dir = File.dirname(settings_dir) if settings_dir && File.file?(settings_dir)
      settings_dir ||= "~/.bosh_bootstrap"
      File.expand_path(settings_dir)
    end
  end

  def settings_path
    File.join(settings_dir, "manifest.yml")
  end

  def settings_ssh_dir
    File.join(settings_dir, "ssh")
  end

  def backup_current_settings_file
    backup_path = "#{settings_path}.bak"
    FileUtils.cp_r(settings_path, backup_path)
  end

end
