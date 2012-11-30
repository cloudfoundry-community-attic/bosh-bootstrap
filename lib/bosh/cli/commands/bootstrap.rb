require "bosh-bootstrap"

module Bosh::Cli::Command
  class Bootstrap < Base
    include Bosh::Cli::DeploymentHelper

    usage "bootstrap deploy"
    desc  "bootstrap a bosh environment"
    def bootstrap

    end

    usage "bootstrap ssh"
    desc  "ssh to a bootstrapped environment"
    def ssh(target)

    end
  end
end
