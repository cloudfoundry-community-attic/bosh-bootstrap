require "thor"
require "highline"
require "settingslogic"
require "fileutils"
require "fog"

module Bosh::Bootstrap
  class Cli < Thor
    include Thor::Actions

    attr_reader :fog_credentials

    desc "local", "Bootstrap bosh, using local server as inception VM"
    method_option :fog, :type => :string, :desc => "fog config file (default: ~/.fog)"
    method_option :"upgrade-deps", :type => :boolean, :desc => "Force upgrade dependencies, packages & gems"
    def local
      load_options # from method_options above

      stage_1_choose_infrastructure_provider
      stage_2_bosh_configuration

      header "Stage 3: Create the Inception VM",
        :skipping => "Running in local mode instead. This is the Inception VM. POW!"

      server = Commander::LocalServer.new

      header "Stage 4: Preparing the Inception VM"
      unless server.run(Bosh::Bootstrap::Stages::StagePrepareInceptionVm.new(settings).commands)
        error "Failed to complete Stage 4: Preparing the Inception VM"
      end
      
      header "Stage 5: Deploying micro BOSH"
      unless server.run(Bosh::Bootstrap::Stages::MicroBoshDeploy.new(settings).commands)
        error "Failed to complete Stage 5: Deploying micro BOSH"
      end
    end

    desc "local", "Bootstrap bosh, using local server as inception VM"
    method_option :fog, :type => :string, :desc => "fog config file (default: ~/.fog)"
    def remote
      load_options # from method_options above

      stage_1_choose_infrastructure_provider
      stage_2_bosh_configuration
    end

    no_tasks do
      def stage_1_choose_infrastructure_provider
        if settings[:fog_credentials]
          header "Stage 1: Choose infrastructure",
            :skipping => "Already selected infrastructure provider"
        else
          header "Stage 1: Choose infrastructure"
          choose_fog_provider
        end
        confirm "Using infrastructure provider #{settings.fog_credentials.provider}"

        unless settings[:region_code]
          choose_provider_region
        end
        if settings[:region_code]
          confirm "Using #{settings.fog_credentials.provider} region #{settings.region_code}"
        else
          confirm "No specific region/data center for #{settings.fog_credentials.provider}"
        end
      end
      
      def stage_2_bosh_configuration
        header "Stage 2: BOSH configuration"
        unless settings[:bosh_name]
          provider, region = settings.bosh_provider, settings.region_code
          default_name = "microbosh_#{provider}_#{region}".gsub(/\W+/, '_')
          bosh_name = HighLine.new.ask("Useful name for Micro BOSH?  ") { |q| q.default = default_name }
          settings[:bosh_name] = bosh_name
          save_settings!
        end
        confirm "Micro BOSH will be named #{settings.bosh_name}"

        unless settings[:bosh_username]
          prompt_for_bosh_credentials
        end
        confirm "After BOSH is created, your username will be #{settings.bosh_username}"

        unless settings[:bosh]
          say "Defaulting to 16Gb persistent disk for BOSH"
          password        = settings.bosh_password # FIXME dual use of password?
          salted_password = `mkpasswd -m sha-512 '#{password}'`.strip
          settings[:bosh] = {}
          settings[:bosh][:password] = password
          settings[:bosh][:salted_password] = salted_password
          settings[:bosh][:persistent_disk] = 16384
          save_settings!
        end
        unless settings.bosh["ip_address"]
          say "Acquiring IP address for micro BOSH..."
          ip_address = acquire_ip_address
          settings.bosh["ip_address"] = ip_address
        end
        unless settings.bosh["ip_address"]
          error "IP address not available/provided currently"
        else
          confirm "Micro BOSH will be assigned IP address #{settings.bosh.ip_address}"
        end
        save_settings!

        if aws?
          unless settings[:bosh_security_group]
            security_group_name = settings.bosh_name
            create_aws_security_group(security_group_name)
          end
          ports = settings.bosh_security_group.ports.values
          confirm "Micro BOSH protected by security group " +
            "named #{settings.bosh_security_group.name}, with ports #{ports}"

          unless settings[:bosh_key_pair]
            key_pair_name = settings.bosh_name
            create_aws_key_pair(key_pair_name)
          end
          confirm "Micro BOSH accessible via key pair named #{settings.bosh_key_pair.name}"
        end

        unless settings[:micro_bosh_stemcell_name]
          settings[:micro_bosh_stemcell_name] = micro_bosh_stemcell_name
          save_settings!
        end

        confirm "Micro BOSH will be created with stemcell #{settings.micro_bosh_stemcell_name}"
      end

      # Display header for a new section of the bootstrapper
      def header(title, options={})
        say "" # golden whitespace
        if skipping = options[:skipping]
          say "Skipping #{title}", [:yellow, :bold]
          say skipping
        else
          say title, [:green, :bold]
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
        settings["fog_path"] = File.expand_path(options[:fog] || "~/.fog")

        if options["upgrade-deps"]
          settings["upgrade_deps"] = options["upgrade-deps"]
        else
          settings.delete("upgrade_deps")
        end
        save_settings!
      end

      # Previously selected settings are stored in a YAML manifest
      # Protects the manifest file with user-only priveleges
      def settings
        @settings ||= begin
          FileUtils.mkdir_p(File.dirname(settings_path))
          unless File.exists?(settings_path)
            File.open(settings_path, "w") do |file|
              file << {}.to_yaml
            end
          end
          FileUtils.chmod 0600, settings_path
          Settingslogic.new(settings_path)
        end
      end

      def save_settings!
        File.open(settings_path, "w") do |file|
          raw_settings_yaml = settings.to_yaml.gsub(" !ruby/hash:Settingslogic", "")
          file << raw_settings_yaml
        end
      end

      def settings_path
        File.expand_path("~/.bosh_bootstrap/manifest.yml")
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
      # At the end, settings.fog_credentials contains the credentials for target IaaS
      # and :provider key for the IaaS name.
      #
      #   {:provider=>"AWS",
      #    :aws_access_key_id=>"PERSONAL_ACCESS_KEY",
      #    :aws_secret_access_key=>"PERSONAL_SECRET"}
      #
      # settings.fog_credentials.provider is the provider name
      # settings.bosh_provider is the BOSH name for the provider (aws,vsphere,openstack)
      #   so as to local stemcells (see +micro_bosh_stemcell_name+)
      def choose_fog_provider
        @fog_providers = {}
        fog_config.inject({}) do |iaas_options, fog_profile|
          profile_name, profile = fog_profile
          if profile[:aws_access_key_id]
            # TODO does fog have inbuilt detection algorithm?
            @fog_providers["AWS (#{profile_name})"] = {
              "provider" => "AWS",
              "aws_access_key_id" => profile[:aws_access_key_id],
              "aws_secret_access_key" => profile[:aws_secret_access_key]
            }
          end
        end
        if @fog_providers.keys.size > 1
          HighLine.new.choose do |menu|
            menu.prompt = "Choose infrastructure:  "
            @fog_providers.each do |label, credentials|
              menu.choice(label) { @fog_credentials = credentials }
            end
          end
        else
          @fog_credentials = @fog_providers.values.first
          if @fog_credentials["aws_access_key_id"]
            @fog_credentials["provider"] = "AWS"
          else
            raise "implement #choose_fog_provider for #{@fog_credentials.inspect}"
          end
        end
        settings[:fog_credentials] = {}
        @fog_credentials.each do |key, value|
          settings[:fog_credentials][key] = value
        end
        setup_bosh_cloud_properties
        settings[:bosh_resources_cloud_properties] = bosh_resources_cloud_properties
        settings[:bosh_provider] = settings.bosh_cloud_properties.keys.first # aws, vsphere...
        save_settings!
      end

      def setup_bosh_cloud_properties
        if aws?
          settings[:bosh_cloud_properties] = {}
          settings[:bosh_cloud_properties][:aws] = {}
          props = settings[:bosh_cloud_properties][:aws]
          props[:access_key_id] = settings.fog_credentials.aws_access_key_id
          props[:secret_access_key] = settings.fog_credentials.aws_secret_access_key
          # props[:ec2_endpoint] = "ec2.REGION.amazonaws.com" - via +choose_aws_region+            
          # props[:default_key_name] = "microbosh"  - via +create_aws_key_pair+
          # props[:ec2_private_key] = "/home/vcap/.ssh/microbosh.pem" - via +create_aws_key_pair+
          # props[:default_security_groups] = ["microbosh"], - via +create_aws_security_group+
        else
          raise "implement #bosh_cloud_properties for #{settings.fog_credentials.provider}"
        end
      end

      def bosh_resources_cloud_properties
        if aws?
          {"instance_type" => "m1.medium"}
        else
          raise "implement #bosh_resources_cloud_properties for #{settings.fog_credentials.provider}"
        end
      end

      # Ask user to provide region information (URI)
      # or choose from a known list of regions (e.g. AWS)
      # Return true if region selected (@region_code is set)
      # Else return false
      def choose_provider_region
        if aws?
          choose_aws_region
        else
          false
        end
      end

      def choose_aws_region
        HighLine.new.choose do |menu|
          menu.prompt = "Choose AWS region:  "
          aws_regions.each do |region|
            menu.choice(region) do
              settings[:region_code] = region
              settings.fog_credentials[:region] = region
              settings.bosh_cloud_properties.aws[:ec2_endpoint] = "ec2.#{region}.amazonaws.com"
              save_settings!
            end
          end
        end
        true
      end

      # supported by fog 1.6.0
      # FIXME weird that fog has no method to return this list
      def aws_regions
        ['ap-northeast-1', 'ap-southeast-1', 'eu-west-1', 'sa-east-1', 'us-east-1', 'us-west-1', 'us-west-2']
      end

      # Creates an AWS security group.
      # Also sets up the bosh_cloud_properties for the remote server
      #
      # Adds settings:
      # * bosh_security_group.name
      # * bosh_security_group.ports
      # * bosh_cloud_properties.aws.default_security_groups
      def create_aws_security_group(security_group_name)
        unless fog_compute.security_groups.get(security_group_name)
          sg = fog_compute.security_groups.create(:name => security_group_name, description: "microbosh")
          settings.bosh_cloud_properties.aws[:default_security_groups] = [security_group_name]
          settings[:bosh_security_group] = {}
          settings[:bosh_security_group][:name] = security_group_name
          settings[:bosh_security_group][:ports] = {}
          settings[:bosh_security_group][:ports][:ssh_access] = 22
          settings[:bosh_security_group][:ports][:message_bus] = 6868
          settings[:bosh_security_group][:ports][:bosh_director] = 25555
          settings[:bosh_security_group][:ports][:aws_registry] = 25888
          settings.bosh_security_group.ports.values.each do |port|
            sg.authorize_port_range(port..port)
          end
          save_settings!
        else
          error "AWS security group '#{security_group_name}' already exists. Rename BOSH or delete old security group manually and re-run CLI."
        end
      end

      # Creates an AWS key pair, and stores the private key
      # in settings manifest.
      # Also sets up the bosh_cloud_properties for the remote server
      # to have the .pem key installed.
      #
      # Adds settings:
      # * bosh_key_pair.name
      # * bosh_key_pair.private_key
      # * bosh_key_pair.fingerprint
      # * bosh_cloud_properties.aws.default_key_name
      # * bosh_cloud_properties.aws.ec2_private_key
      def create_aws_key_pair(key_pair_name)
        unless fog_compute.key_pairs.get(key_pair_name)
          kp = fog_compute.key_pairs.create(:name => key_pair_name)
          settings[:bosh_key_pair] = {}
          settings[:bosh_key_pair][:name] = key_pair_name
          settings[:bosh_key_pair][:private_key] = kp.private_key
          settings[:bosh_key_pair][:fingerprint] = kp.fingerprint
          settings[:bosh_cloud_properties][:aws][:default_key_name] = key_pair_name
          settings[:bosh_cloud_properties][:aws][:ec2_private_key] = "/home/vcap/.ssh/#{key_pair_name}.pem"
          save_settings!
        else
          error "AWS key pair '#{key_pair_name}' already exists. Rename BOSH or delete old key pair manually and re-run CLI."
        end
      end

      # Provision or provide an IP address to use
      # For AWS, it will dynamically provision an elastic IP
      # For other providers, it may opt to prompt for a static IP
      # to use.
      def acquire_ip_address
        if aws?
          provision_elastic_ip_address
        else
          HighLine.new.ask("What static IP to use for micro BOSH?  ")
        end
      end

      # using fog, provision an elastic IP address
      # TODO what is the error raised if no IPs available?
      # returns an IP address as a string, e.g. "1.2.3.4"
      def provision_elastic_ip_address
        address = fog_compute.addresses.create
        address.public_ip
      end

      # fog connection object to Compute tasks (VMs, IP addresses)
      def fog_compute
        # Fog::Compute.new requires Hash with keys that are symbols
        # but Settings converts all keys to strings
        # So create a version of settings.fog_credentials with symbol keys
        credentials_with_symbols = settings.fog_credentials.inject({}) do |creds, key_pair|
          key, value = key_pair
          creds[key.to_sym] = value
          creds
        end
        @fog_compute ||= Fog::Compute.new(credentials_with_symbols)
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
        settings.fog_path
      end

      def aws?
        settings.fog_credentials.provider == "AWS"
      end

      def prompt_for_bosh_credentials
        prompt = HighLine.new
        say "Please enter a user/password for the BOSH that will be created."
        settings[:bosh_username] = prompt.ask("BOSH username: ")
        settings[:bosh_password] = prompt.ask("BOSH password: ") { |q| q.echo = "x" }
        save_settings!
      end

      # Returns the latest micro-bosh stemcell
      # for the target provider (aws, vsphere, openstack)
      def micro_bosh_stemcell_name
        @micro_bosh_stemcell_name ||= begin
          provider = settings.bosh_provider # aws, vsphere, openstack
          scope = ",stable" # latest stable micro-bosh stemcell by default
          bosh_stemcells_cmd = "bosh public stemcells --tags micro,#{provider}#{scope}"
          say "Locating micro-bosh stemcell, running '#{bosh_stemcells_cmd}'..."
          `#{bosh_stemcells_cmd} | grep micro | awk '{ print $2 }' | head -n 1`.strip
        end
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