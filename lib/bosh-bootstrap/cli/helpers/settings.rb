require "settingslogic"
require "fileutils"

module Bosh::Bootstrap::Cli::Helpers::Settings
  include FileUtils

  # The base directory for holding the manifest settings file
  # and private keys
  #
  # Defaults to ~/.bosh_inception; and can be overridden with either:
  # * $SETTINGS - to a folder (supported method)
  def settings_dir
    @settings_dir ||= File.expand_path(ENV["SETTINGS"] || "~/.microbosh")
  end

  def settings_dir=(settings_dir)
    @settings_dir = File.expand_path(settings_dir)
    reload_settings!
  end

  def settings_ssh_dir
    File.join(settings_dir, "ssh")
  end

  def settings_path
    @settings_path ||= File.join(settings_dir, "settings.yml")
  end

  def settings
    @settings ||= begin
      unless File.exists?(settings_path)
        mkdir_p(settings_dir)
        File.open(settings_path, "w") { |file| file << "--- {}" }
      end
      chmod(0600, settings_path)
      chmod(0700, settings_ssh_dir) if File.directory?(settings_ssh_dir)
      Settingslogic.new(settings_path)
    end
  end

  # Set a nested setting with "key1.key2.key3" notation
  def setting(nested_key, value)
    settings.set(nested_key, value)
    save_settings!
  end

  # Saves current nested Settingslogic into pure Hash-based YAML file
  # Recreates accessors on Settingslogic object (since something has changed)
  def save_settings!
    File.open(settings_path, "w") { |f| f << settings.to_nested_hash.to_yaml }
    settings.create_accessors!
  end

  def reload_settings!
    @settings = nil
    settings
  end

  def migrate_old_settings
  end
end
