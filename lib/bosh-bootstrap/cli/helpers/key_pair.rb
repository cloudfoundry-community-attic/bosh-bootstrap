require "cyoi/cli/key_pair"
require "readwritesettings"
require "fileutils"

module Bosh::Bootstrap::Cli::Helpers::KeyPair
  include FileUtils

  def setup_keypair
    key_pair_name = settings.exists?("key_pair.name") || settings.bosh.name
    cli = Cyoi::Cli::KeyPair.new([key_pair_name, settings_dir])
    cli.execute!
    reload_settings!

    key_pair = Bosh::Bootstrap::KeyPair.new(settings_dir, settings.key_pair.name, settings.key_pair.private_key)
    key_pair.execute!
    settings.set("key_pair.path", key_pair.path)
  end

end