# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "settingslogic"
module Bosh; module Bootstrap; module Helpers; end; end; end

# Set a nested setting with "key1.key2.key3" notation
#
# Assumes +settings+ contains the settings
module Bosh::Bootstrap::Helpers::SettingsSetter

  # Let's you navigate to a nested setting, do something with it,
  # and then saves any changes to settings.
  # Usage:
  #   with_setting "inception" { |s| s["host"] = "1.2.3.4" }
  #   with_setting "a.b.c" { |s| s["value"] = "1.2.3.4" }
  def with_setting(nested_key, &block)
    target_settings_field = settings
    settings_key_portions = nested_key.split(".")
    parent_key_portions, final_key = settings_key_portions[0..-2], settings_key_portions[-1]
    parent_key_portions.each do |key_portion|
      target_settings_field[key_portion] ||= {}
      target_settings_field = target_settings_field[key_portion]
    end

    target_settings_field[final_key] ||= {}
    yield target_settings_field[final_key]
    save_settings!
  end

  def setting(nested_key, value)
    target_settings_field = settings
    settings_key_portions = nested_key.split(".")
    parent_key_portions, final_key = settings_key_portions[0..-2], settings_key_portions[-1]
    parent_key_portions.each do |key_portion|
      target_settings_field[key_portion] ||= {}
      target_settings_field = target_settings_field[key_portion]
    end
    target_settings_field[final_key] = value
  end

end