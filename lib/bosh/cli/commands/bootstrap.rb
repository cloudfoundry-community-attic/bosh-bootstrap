# Copyright (c) 2012-2013 Stark & Wayne, LLC

require "bosh-bootstrap"

module Bosh::Cli::Command
  class Bootstrap < Base
    usage "bootstrap"
    desc  "show bootstrap sub-commands"
    def help
      say("bosh bootstrap sub-commands:")
      nl
      cmds = Bosh::Cli::Config.commands.values.find_all {|c|
        c.usage =~ /^bootstrap/
      }
      Bosh::Cli::Command::Help.list_commands(cmds)
    end

    usage "bootstrap deploy"
    desc "Configure and bootstrap a Micro BOSH; or deploy/upgrade existing Micro Bosh"
    def deploy
      require "bosh-bootstrap/cli/commands/deploy"
      deploy_cmd = Bosh::Bootstrap::Cli::Commands::Deploy.new
      deploy_cmd.perform
    end

    usage "bootstrap ssh"
    desc "SSH into Micro BOSH"
    def ssh
      require "bosh-bootstrap/cli/commands/ssh"
      cmd = Bosh::Bootstrap::Cli::Commands::SSH.new
      cmd.perform
    end

    usage "bootstrap delete"
    desc "Delete existing Micro Bosh (does not delete any bosh deployments running)"
    def delete
      require "bosh-bootstrap/cli/commands/delete"
      cmd = Bosh::Bootstrap::Cli::Commands::Delete.new
      cmd.perform
    end
  end
end
