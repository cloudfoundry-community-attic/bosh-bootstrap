require "thor"
require "highline"
require "settingslogic"
require "fileutils"

module Bosh::Bootstrap
  class Cli < Thor
    include Thor::Actions

    attr_reader :iaas_credentials
    attr_reader :region_code

    desc "local", "Bootstrap bosh, using local server as inception VM"
    method_option :fog, :type => :string, :desc => "fog config file (default: ~/.fog)"
    def local
      load_options # from method_options above

      header "Stage 1: Choose infrastructure"
      choose_fog_provider
      confirm "Using #{provider_name} infrastructure provider."

      choose_provider_region
      confirm "Using #{provider_name} #{region_code} region."

      header "Stage 2: Configuration"

      header "Skipping Stage 3: Create the Inception VM",
        :skipping => "Running in local mode instead. This is the Inception VM. POW!"

      server = Commander::LocalServer.new

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

      def error(message)
        say message, :red
        exit 1
      end

      def confirm(message)
        say "Confirming: #{message}", green
        say "" # bonus golden whitespace
      end

      def load_options
        @fog_config_path = options[:fog] if options[:fog]        
      end

      # Previously selected settings are stored in a YAML manifest
      def settings
        @settings ||= begin
          manifest_path = File.expand_path("~/.bosh_bootstrap/manifest.yml")
          FileUtils.mkdir_p(File.dirname(manifest_path))
          unless File.exists?(manifest_path)
            File.open(manifest_path, "w") do |file|
              file << {}.to_yaml
            end
          end
          Settingslogic.new(manifest_path)
        end
      end

      # Displays a prompt for known IaaS that are configured
      # within .fog config file.
      #
      # For example:
      #
      # 1. AWS (default)
      # 2. AWS (bosh)
      # Choose infrastructure:  1
      #
      # If .fog config only contains one provider, do not prompt.
      #
      # fog config file looks like:
      # :default:
      #   :aws_access_key_id:     PERSONAL_ACCESS_KEY
      #   :aws_secret_access_key: PERSONAL_SECRET
      # :bosh:
      #   :aws_access_key_id:     SPECIAL_IAM_ACCESS_KEY
      #   :aws_secret_access_key: SPECIAL_IAM_SECRET_KEY
      #
      # Convert this into:
      # { "AWS (default)" => {:aws_access_key_id => ...}, "AWS (bosh)" => {...} }
      #
      # Then display options to user to choose.
      #
      # Currently detects following fog providers:
      # * AWS
      #
      # At the end, @iaas_credentials contains the credentials for target IaaS
      # and :provider key for the IaaS name.
      #
      #   {:provider=>"AWS",
      #    :aws_access_key_id=>"PERSONAL_ACCESS_KEY",
      #    :aws_secret_access_key=>"PERSONAL_SECRET"}
      def choose_fog_provider
        @fog_providers = {}
        fog_config.inject({}) do |iaas_options, fog_profile|
          profile_name, keys = fog_profile
          if keys[:aws_access_key_id]
            # TODO does fog have inbuilt detection algorithm?
            @fog_providers["AWS (#{profile_name})"] = {
              :provider => "AWS",
              :aws_access_key_id => keys[:aws_access_key_id],
              :aws_secret_access_key => keys[:aws_secret_access_key]
            }
          end
        end
        if @fog_providers.keys.size > 1
          HighLine.new.choose do |menu|
            menu.prompt = "Choose infrastructure:  "
            @fog_providers.each do |label, credentials|
              menu.choice(label) { @iaas_credentials = credentials }
            end
          end
        else
          @iaas_credentials = @fog_providers.values.first
        end
      end

      def choose_provider_region
        case provider_name.to_sym
        when :AWS
          choose_aws_region
        end
      end

      def choose_aws_region
        HighLine.new.choose do |menu|
          menu.prompt = "Choose AWS region:  "
          aws_regions.each do |region|
            menu.choice(region) { @aws_region = region; @region_code = region }
          end
        end
      end

      # supported by fog
      # FIXME weird that fog has no method to return this list
      def aws_regions
        ['ap-northeast-1', 'ap-southeast-1', 'eu-west-1', 'us-east-1', 'us-west-1', 'us-west-2', 'sa-east-1']
      end

      def fog_config
        @fog_config ||= begin
          unless File.exists?(fog_config_path)
            error "Please create a #{fog_config_path} fog configuration file"
          end
          say "Found infrastructure API credentials at #{fog_config_path} (override with --fog)"
          YAML.load_file(fog_config_path)
        end
      end

      def fog_config_path
        File.expand_path(@fog_config_path || "~/.fog")
      end

      def provider_name
        raise "run choose_fog_provider first" unless @iaas_credentials
        @iaas_credentials[:provider]
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