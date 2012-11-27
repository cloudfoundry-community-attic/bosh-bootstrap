require "thor"

module Bosh::Bootstrap
  class Cli < Thor
    include Thor::Actions

    desc "local", "Bootstrap bosh, using local server as inception VM"
    def local
      server = Commander::LocalServer.new

      header "Stage 1: Choose infrastructure"
      header "Stage 2: Configuration"

      header "Skipping Stage 3: Create the Inception VM",
        :skipping => "Running in local mode instead. This is the Inception VM. POW!"

      header "Stage 4: Preparing the Inception VM"
      server.run(Bosh::Bootstrap::Stages::StagePrepareInceptionVm.new.commands) # TODO stop on failure
    end

    no_tasks do
      # Display header for a new section of the bootstrapper
      def header(title, options={})
        say "" # golden whitespace
        if skipping = options[:skipping]
          say "Skipping #{title}", :yellow
          say skipping
        else
          say title, :green
        end
        say "" # more golden whitespace
      end

      def cyan; "\033[36m" end
      def clear; "\033[0m" end
      def bold; "\033[1m" end
      def red; "\033[31m" end
      def green; "\033[32m" end
      def yellow; "\033[33m" end
    end
  end
end