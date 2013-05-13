# Copyright (c) 2012-2013 Stark & Wayne, LLC

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
      raise "not implemented yet"
    end

    usage "bootstrap delete"
    desc "Delete existing Micro Bosh (does not delete any bosh deployments running)"
    def delete
      raise "not implemented yet"
    end
  end
end