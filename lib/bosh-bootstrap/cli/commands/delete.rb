# Copyright (c) 2012-2013 Stark & Wayne, LLC

module Bosh; module Bootstrap; module Cli; module Commands; end; end; end; end

require "bosh-bootstrap/cli/helpers"

# Runs SSH to the microbosh server
class Bosh::Bootstrap::Cli::Commands::Delete
  include Bosh::Bootstrap::Cli::Helpers

  def perform
    chdir(deployment_dir) do
      bundle "exec bosh -n micro deployment #{bosh_name}"
      bundle "exec bosh -n micro delete"
    end
  end

  protected
  def bosh_name
    settings.bosh.name
  end

  def deployment_dir
    File.join(settings_dir, "deployments")
  end
end