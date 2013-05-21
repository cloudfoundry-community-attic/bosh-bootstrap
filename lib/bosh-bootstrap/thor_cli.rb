require "thor"
require "bosh-bootstrap"

module Bosh::Bootstrap
  class ThorCli < Thor

    desc "deploy", "Configure and bootstrap a micro bosh; or deploy/upgrade existing Micro Bosh"
    def deploy
      require "bosh-bootstrap/cli/commands/deploy"
      deploy_cmd = Bosh::Bootstrap::Cli::Commands::Deploy.new
      deploy_cmd.perform
    end

    desc "ssh", "SSH into micro bosh"
    def ssh
      require "bosh-bootstrap/cli/commands/ssh"
      cmd = Bosh::Bootstrap::Cli::Commands::SSH.new
      cmd.perform
    end

    desc "delete", "Delete existing Micro Bosh (does not delete any bosh deployments running)"
    def delete
      require "bosh-bootstrap/cli/commands/delete"
      cmd = Bosh::Bootstrap::Cli::Commands::Delete.new
      cmd.perform
    end
  end
end