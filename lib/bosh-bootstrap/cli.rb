require "thor"

module Bosh::Bootstrap
  class Cli < Thor
    include Thor::Actions

    desc "local", "Bootstrap bosh, using local server as inception VM"
    def local
      server = Commander::LocalServer.new
      say "Skipping Stage 3: Create the Inception VM", :yellow
      say "Stage 4: Preparing the Inception VM", :green
      server.run(Bosh::Bootstrap::Stages::StagePrepareInceptionVm.new.commands)
    end

    desc "demo", "Show some sample commands"
    def demo
      commands = Bosh::Bootstrap::Commander::Commands.new do |server|
        server.create "vcap user", <<-BASH
          #!/usr/bin/env bash

          echo 'creating vcap user.......'
        BASH

        server.install "rvm & ruby", <<-BASH
          #!/usr/bin/env bash

          echo 'ruby now installed: #{`ruby -v`.strip}
        BASH

        server.show "readme", ""
      end
      Commander::LocalServer.new.run(commands)
    end

    no_tasks do
      def cyan; "\033[36m" end
      def clear; "\033[0m" end
      def bold; "\033[1m" end
      def red; "\033[31m" end
      def green; "\033[32m" end
      def yellow; "\033[33m" end
    end
  end
end