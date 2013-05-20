# Copyright (c) 2012-2013 Stark & Wayne, LLC

module Bosh; module Bootstrap; module Cli; module Commands; end; end; end; end

require "bosh-bootstrap/cli/helpers"

# for the #sh helper
require "rake"
require "rake/file_utils"

# Runs SSH to the microbosh server
class Bosh::Bootstrap::Cli::Commands::SSH
  include Bosh::Bootstrap::Cli::Helpers
  include FileUtils

  def perform
    sh "ssh -i #{private_key_path} #{user}@#{host}"
  end

  protected
  def user
    "vcap"
  end

  def host
    settings.address.ip
  end

  def private_key_path
    File.expand_path(settings.key_pair.path)
  end
end