require "thor"
require "highline"
require "fileutils"

# for the #sh helper
require "rake"
require "rake/file_utils"

require "escape"

require "bosh-bootstrap/helpers"

module Bosh::Bootstrap
  class Cli < Thor
    include Thor::Actions
    include Bosh::Bootstrap::Helpers::FogSetup
    include Bosh::Bootstrap::Helpers::Settings
    include FileUtils

    attr_reader :fog_credentials
    attr_reader :server

    desc "deploy", "Bootstrap Micro BOSH, and optionally an Inception VM"
    method_option :fog, :type => :string, :desc => "fog config file (default: ~/.fog)"
    method_option :"private-key", :type => :string, :desc => "Local passphrase-less private key path"
    method_option :"upgrade-deps", :type => :boolean, :desc => "Force upgrade dependencies, packages & gems"
    method_option :"edge-deployer", :type => :boolean, :desc => "Install bosh deployer from git instead of rubygems"
    method_option :"latest-stemcell", :type => :boolean, :desc => "Use latest micro-bosh stemcell; possibly not tagged stable"
    method_option :"edge-stemcell", :type => :boolean, :desc => "Create custom stemcell from BOSH git source"
    def deploy
      load_deploy_options # from method_options above

      deploy_stage_1_choose_infrastructure_provider
      deploy_stage_2_bosh_configuration
      deploy_stage_3_create_allocate_inception_vm
      deploy_stage_4_prepare_inception_vm
      deploy_stage_5_deploy_micro_bosh
      deploy_stage_6_setup_new_bosh
    end

    # desc "delete", "Delete Micro BOSH"
    # method_option :all, :type => :boolean, :desc => "Delete all micro-boshes and inception VM [coming soon]"
    # def delete
    #   delete_stage_1_target_inception_vm
    # 
    #   if options[:all]
    #     error "I'm sorry; the awesome --all flag is not yet implemented"
    #     delete_all_stage_2_delete_micro_boshes
    #     delete_all_stage_3_delete_inception_vm
    #   else
    #     delete_one_stage_2_delete_micro_bosh
    #   end
    # end
    # 
    desc "ssh [COMMAND]", "Open an ssh session to the inception VM [do nothing if local machine is inception VM]"
    long_desc <<-DESC
      If a command is supplied, it will be run, otherwise a session will be
      opened.
    DESC
    def ssh(cmd=nil)
      run_ssh_command_or_open_tunnel(cmd)
    end

    no_tasks do
      DEFAULT_INCEPTION_VOLUME_SIZE = 32 # Gb

      def deploy_stage_1_choose_infrastructure_provider
        header "Stage 1: Choose infrastructure"
        unless settings[:fog_credentials]
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
      
      def deploy_stage_2_bosh_configuration
        header "Stage 2: BOSH configuration"
        unless settings[:bosh_name]
          provider, region = settings.bosh_provider, settings.region_code
          if region
            default_name = "microbosh-#{provider}-#{region}".gsub(/\W+/, '-')
          else
            default_name = "microbosh-#{provider}".gsub(/\W+/, '-')
          end
          bosh_name = hl.ask("Useful name for Micro BOSH?  ") { |q| q.default = default_name }
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
          settings[:bosh] = {}
          settings[:bosh][:password] = password
          settings[:bosh][:persistent_disk] = 16384
          save_settings!
        end
        unless settings[:bosh]["ip_address"]
          say "Acquiring IP address for micro BOSH..."
          ip_address = acquire_ip_address
          settings[:bosh]["ip_address"] = ip_address
        end
        unless settings[:bosh]["ip_address"]
          error "IP address not available/provided currently"
        else
          confirm "Micro BOSH will be assigned IP address #{settings[:bosh]['ip_address']}"
        end
        save_settings!

        unless settings[:bosh_security_group]
          security_group_name = settings.bosh_name
          create_security_group(security_group_name)
        end
        ports = settings.bosh_security_group.ports.values
        confirm "Micro BOSH protected by security group " +
          "named #{settings.bosh_security_group.name}, with ports #{ports}"

        unless settings[:bosh_key_pair]
          key_pair_name = settings.bosh_name
          create_key_pair(key_pair_name)
        end
        confirm "Micro BOSH accessible via key pair named #{settings.bosh_key_pair.name}"

        unless settings[:micro_bosh_stemcell_name]
          settings[:micro_bosh_stemcell_name] = micro_bosh_stemcell_name
          save_settings!
        end

        confirm "Micro BOSH will be created with stemcell #{settings.micro_bosh_stemcell_name}"
      end

      def deploy_stage_3_create_allocate_inception_vm
        header "Stage 3: Create/Allocate the Inception VM"
        unless settings["inception"] && settings["inception"]["host"]
          hl.choose do |menu|
            menu.prompt = "Create or specify an Inception VM:  "
            if aws? || openstack?
              menu.choice("create new inception VM") do
                aws? ? boot_aws_inception_vm : boot_openstack_inception_vm
              end
            end
            menu.choice("use an existing Ubuntu server") do
              settings["inception"] = {}
              settings["inception"]["host"] = \
                hl.ask("Host address (IP or domain) to inception VM? ")
              settings["inception"]["username"] = \
                hl.ask("Username that you have SSH access to? ") {|q| q.default = "ubuntu"}
            end
            menu.choice("use this server (must be ubuntu & on same network as bosh)") do
              # dummy data for settings.inception
              settings["inception"] = {}
              settings["inception"]["username"] = `whoami`.strip
            end
          end
        end
        # If successfully validate inception VM, then save those settings.
        save_settings!

        if settings["inception"]["host"]
          @server = Commander::RemoteServer.new(settings.inception.host)
          confirm "Using inception VM #{settings.inception.username}@#{settings.inception.host}"
        else
          @server = Commander::LocalServer.new
          confirm "Using this server as the inception VM"
        end
        unless settings["inception"]["validated"]
          unless server.run(Bosh::Bootstrap::Stages::StageValidateInceptionVm.new(settings).commands)
            error "Failed to complete Stage 3: Create/Allocate the Inception VM"
          end
          settings["inception"]["validated"] = true
        end
        # If successfully validate inception VM, then save those settings.
        save_settings!
      end

      def deploy_stage_4_prepare_inception_vm
        unless settings["inception"]["prepared"] && !settings["upgrade_deps"]
          header "Stage 4: Preparing the Inception VM"
          unless server.run(Bosh::Bootstrap::Stages::StagePrepareInceptionVm.new(settings).commands)
            error "Failed to complete Stage 4: Preparing the Inception VM"
          end
          # Settings are updated by this stage
          # it generates a salted password from settings.bosh.password
          # and stores it in settings.bosh.salted_password
          settings["inception"]["prepared"] = true
          save_settings!
        else
          header "Stage 4: Preparing the Inception VM", :skipping => "Already prepared inception VM."
        end
      end

      def deploy_stage_5_deploy_micro_bosh
        header "Stage 5: Deploying micro BOSH"
        unless server.run(Bosh::Bootstrap::Stages::MicroBoshDeploy.new(settings).commands)
          error "Failed to complete Stage 5: Deploying micro BOSH"
        end

        confirm "Successfully built micro BOSH"
      end

      def deploy_stage_6_setup_new_bosh
        # TODO change to a polling test of director being available
        say "Pausing to wait for BOSH Director..."
        sleep 5

        header "Stage 6: Setup bosh"
        unless server.run(Bosh::Bootstrap::Stages::SetupNewBosh.new(settings).commands)
          error "Failed to complete Stage 6: Setup bosh"
        end

        say "Locally targeting and login to new BOSH..."
        sh "bosh -u #{settings.bosh_username} -p #{settings.bosh_password} target #{settings.bosh.ip_address}"
        sh "bosh login #{settings.bosh_username} #{settings.bosh_password}"

        save_settings!

        confirm "You are now targeting and logged in to your BOSH"
      end

      def delete_stage_1_target_inception_vm
        header "Stage 1: Target inception VM to use to delete micro-bosh"
        if settings["inception"]["host"]
          @server = Commander::RemoteServer.new(settings.inception.host)
          confirm "Using inception VM #{settings.inception.username}@#{settings.inception.host}"
        else
          @server = Commander::LocalServer.new
          confirm "Using this server as the inception VM"
        end
      end

      def delete_one_stage_2_delete_micro_bosh
        header "Stage 2: Deleting micro BOSH"
        unless server.run(Bosh::Bootstrap::Stages::MicroBoshDelete.new(settings).commands)
          error "Failed to complete Stage 1: Delete micro BOSH"
        end
        save_settings!
      end

      def delete_all_stage_2_delete_micro_boshes
        
      end

      def delete_all_stage_3_delete_inception_vm
        
      end

      def run_ssh_command_or_open_tunnel(cmd)
        unless settings[:inception]
          say "No inception VM being used", :yellow
          exit 0
        end
        unless host = settings.inception[:host]
          exit "Inception VM has not finished launching; run to complete: #{self.class.banner_base} deploy"
        end
        username = 'vcap'
        exit system Escape.shell_command(['ssh', "#{username}@#{host}", cmd].compact)

        # TODO how to use the specific private_key_path as configured in settings
        # _, private_key_path = local_ssh_key_paths
        # exit system Escape.shell_command(['ssh', "-i #{private_key_path}", "#{username}@#{host}", cmd].compact)
        #
        # Currently this shows:
        # Warning: Identity file  /Users/drnic/.ssh/id_rsa not accessible: No such file or directory.
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

      def load_deploy_options
        settings["fog_path"] = File.expand_path(options[:fog] || "~/.fog")

        settings["bosh_git_source"] = options[:"edge-deployer"] # use bosh git repo instead of rubygems

        # determine which micro-bosh stemcell to download/create
        if options[:"latest-stemcell"]
          settings["micro_bosh_stemcell_type"] = "latest"
          settings["micro_bosh_stemcell_name"] = nil # force name to be refetched
        elsif options[:"edge-stemcell"]
          settings["micro_bosh_stemcell_type"] = "custom"
          settings["micro_bosh_stemcell_name"] = "custom"
        else
          # may have already been set from previous deploy run
          settings["micro_bosh_stemcell_type"] ||= "stable"
        end

        # once a stemcell is downloaded or created; these fields above should
        # be uploaded with values such as:
        #  -> settings["micro_bosh_stemcell_name"] = "micro-bosh-stemcell-aws-0.8.1.tgz"

        if options["private-key"]
          private_key_path = File.expand_path(options["private-key"])
          unless File.exists?(private_key_path)
            error "Cannot find a file at #{private_key_path}"
          end
          public_key_path = "#{private_key_path}.pub"
          unless File.exists?(public_key_path)
            error "Cannot find a file at #{public_key_path}"
          end

          settings["local"] ||= {}
          settings["local"]["private_key_path"] = private_key_path
          settings["local"]["public_key_path"] = public_key_path
        end

        if options["upgrade-deps"]
          settings["upgrade_deps"] = options["upgrade-deps"]
        else
          settings.delete("upgrade_deps")
        end
        save_settings!
      end

      # Displays a prompt for known IaaS that are configured
      # within .fog config file.
      #
      # For example:
      #
      # 1. AWS (default)
      # 2. AWS (bosh)
      # 3. Alternate credentials
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
      # * OpenStack
      #
      # If "Alternate credentials" is selected, then user is prompted for fog
      # credentials:
      # * provider?
      # * access keys?
      # * API URI or region?
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
        # Prepare menu options:
        # each provider/profile name gets a menu choice option
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
          if profile[:openstack_username]
            # TODO does fog have inbuilt detection algorithm?
            @fog_providers["OpenStack (#{profile_name})"] = {
              "provider" => "OpenStack",
              "openstack_username" => profile[:openstack_username],
              "openstack_api_key" => profile[:openstack_api_key],
              "openstack_tenant" => profile[:openstack_tenant],
              "openstack_auth_url" => profile[:openstack_auth_url]
            }
          end
        end
        # Display menu
        # Include "Alternate credentials" as the last option
        if @fog_providers.keys.size > 0
          hl.choose do |menu|
            menu.prompt = "Choose infrastructure:  "
            @fog_providers.each do |label, credentials|
              menu.choice(label) { @fog_credentials = credentials }
            end
            menu.choice("Alternate credentials") { prompt_for_alternate_fog_credentials }
          end
        else
          prompt_for_alternate_fog_credentials
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

      # If no .fog file is found, or if user chooses "Alternate credentials",
      # then this method prompts the user:
      # * provider?
      # * access keys?
      # * API URI or region?
      #
      # Populates +@fog_credentials+ with a Hash that includes :provider key
      # For example:
      # {
      #   :provider => "AWS",
      #   :aws_access_key_id => ACCESS_KEY,
      #   :aws_secret_access_key => SECRET_KEY
      # }
      def prompt_for_alternate_fog_credentials
        say ""  # glorious whitespace
        creds = {}
        hl.choose do |menu|
          menu.prompt = "Choose infrastructure:  "
          menu.choice("AWS") do
            creds[:provider] = "AWS"
            creds[:aws_access_key_id] = hl.ask("Access key: ")
            creds[:aws_secret_access_key] = hl.ask("Secret key: ")
          end
          menu.choice("OpenStack") do
            creds[:provider] = "OpenStack"
            creds[:openstack_username] = hl.ask("Username: ")
            creds[:openstack_api_key] = hl.ask("API key: ")
            creds[:openstack_tenant] = hl.ask("Tenant: ")
            creds[:openstack_auth_url] = hl.ask("Authorization URL: ")
          end
        end
        @fog_credentials = creds
      end

      def setup_bosh_cloud_properties
        if aws?
          settings[:bosh_cloud_properties] = {}
          settings[:bosh_cloud_properties][:aws] = {}
          props = settings[:bosh_cloud_properties][:aws]
          props[:access_key_id] = settings.fog_credentials.aws_access_key_id
          props[:secret_access_key] = settings.fog_credentials.aws_secret_access_key
          # props[:ec2_endpoint] = "ec2.REGION.amazonaws.com" - via +choose_aws_region+
          # props[:region] = REGION - via +choose_aws_region+            
          # props[:default_key_name] = "microbosh"  - via +create_aws_key_pair+
          # props[:ec2_private_key] = "/home/vcap/.ssh/microbosh.pem" - via +create_aws_key_pair+
          # props[:default_security_groups] = ["microbosh"], - via +create_aws_security_group+
        elsif openstack?
          settings[:bosh_cloud_properties] = {}
          settings[:bosh_cloud_properties][:openstack] = {}
          props = settings[:bosh_cloud_properties][:openstack]
          props[:username] = settings.fog_credentials.openstack_username
          props[:api_key] = settings.fog_credentials.openstack_api_key
          props[:tenant] = settings.fog_credentials.openstack_tenant
          props[:auth_url] = settings.fog_credentials.openstack_auth_url
          # props[:default_key_name] = "microbosh"  - via +create_openstack_key_pair+
          # props[:private_key] = "/home/vcap/.ssh/microbosh.pem" - via +create_openstack_key_pair+
          # props[:default_security_groups] = ["microbosh"], - via +create_openstack_security_group+
        else
          raise "implement #bosh_cloud_properties for #{settings.fog_credentials.provider}"
        end
      end

      def bosh_resources_cloud_properties
        if aws?
          {"instance_type" => "m1.medium"}
        elsif openstack?
          # TODO: Ask for instance type
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
          prompt_openstack_region
        end
      end

      def choose_aws_region
        aws_regions = provider.region_labels
        default_aws_region = provider.default_region_label

        hl.choose do |menu|
          menu.prompt = "Choose AWS region (default: #{default_aws_region}): "
          aws_regions.each do |region|
            menu.choice(region) do
              settings["region_code"] = region
              settings["fog_credentials"]["region"] = region
              settings["bosh_cloud_properties"]["aws"]["region"] = region
              settings["bosh_cloud_properties"]["aws"]["ec2_endpoint"] = "ec2.#{region}.amazonaws.com"
              save_settings!
            end
            menu.default = default_aws_region
          end
        end
        reset_fog_compute
        true
      end

      def prompt_openstack_region
        prompt = hl
        region = prompt.ask("OpenStack Region: ") { |q| q.default = nil }
        if region.strip != ""
          settings[:region_code] = region
          settings["fog_credentials"]["openstack_region"] = region
          settings["bosh_cloud_properties"]["openstack"]["region"] = region
          save_settings!
          reset_fog_compute
          true
        else
          settings["region_code"] = nil
          false
        end
      end

      # Creates a security group.
      # Also sets up the bosh_cloud_properties for the remote server
      #
      # Adds settings:
      # * bosh_security_group.name
      # * bosh_security_group.ports
      # * bosh_cloud_properties.<bosh_provider>.default_security_groups
      def create_security_group(security_group_name)
        ports = {
          ssh_access: 22,
          nats_server: 4222,
          message_bus: 6868,
          blobstore: 25250,
          bosh_director: 25555
        }
        if aws?
          ports[:aws_registry] = 25777
        elsif openstack?
          ports[:openstack_registry] = 25889
        end

        provider.create_security_group(security_group_name, "microbosh", ports)

        settings["bosh_cloud_properties"][provider_name]["default_security_groups"] = [security_group_name]
        settings["bosh_security_group"] = {}
        settings["bosh_security_group"]["name"] = security_group_name
        settings["bosh_security_group"]["ports"] = {}
        ports.each { |name, port| settings["bosh_security_group"]["ports"][name.to_s] = port }
        save_settings!
      end

      # Creates a key pair.
      def create_key_pair(key_pair_name)
        if aws?
          create_aws_key_pair(key_pair_name)
        elsif openstack?
          create_openstack_key_pair(key_pair_name)
        else
          raise "implement #create_key_pair for #{settings.fog_credentials.provider}"
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
          say "creating key pair #{key_pair_name}..."
          kp = fog_compute.key_pairs.create(:name => key_pair_name)
          settings[:bosh_key_pair] = {}
          settings[:bosh_key_pair][:name] = key_pair_name
          settings[:bosh_key_pair][:private_key] = kp.private_key
          settings[:bosh_key_pair][:fingerprint] = kp.fingerprint
          settings["bosh_cloud_properties"]["aws"]["default_key_name"] = key_pair_name
          settings["bosh_cloud_properties"]["aws"]["ec2_private_key"] = "/home/vcap/.ssh/#{key_pair_name}.pem"
          save_settings!
        else
          error "AWS key pair '#{key_pair_name}' already exists. Rename BOSH or delete old key pair manually and re-run CLI."
        end
      end

      # Creates an OpenStack key pair, and stores the private key
      # in settings manifest.
      # Also sets up the bosh_cloud_properties for the remote server
      # to have the .pem key installed.
      #
      # Adds settings:
      # * bosh_key_pair.name
      # * bosh_key_pair.private_key
      # * bosh_key_pair.fingerprint
      # * bosh_cloud_properties.openstack.default_key_name
      # * bosh_cloud_properties.openstack.ec2_private_key
      def create_openstack_key_pair(key_pair_name)
        unless fog_compute.key_pairs.get(key_pair_name)
          say "creating key pair #{key_pair_name}..."
          kp = fog_compute.key_pairs.create(:name => key_pair_name)
          settings[:bosh_key_pair] = {}
          settings[:bosh_key_pair][:name] = key_pair_name
          settings[:bosh_key_pair][:private_key] = kp.private_key
          settings[:bosh_key_pair][:fingerprint] = kp.fingerprint
          settings["bosh_cloud_properties"]["openstack"]["default_key_name"] = key_pair_name
          settings["bosh_cloud_properties"]["openstack"]["private_key"] = "/home/vcap/.ssh/#{key_pair_name}.pem"
          save_settings!
        else
          error "OpenStack key pair '#{key_pair_name}' already exists. Rename BOSH or delete old key pair manually and re-run CLI."
        end
      end

      # Provisions an AWS m1.small VM as the inception VM
      # Updates settings.inception.host/username
      #
      # NOTE: if any stage fails, when the CLI is re-run
      # and "create new server" is selected again, the process should
      # complete
      #
      # Assumes that local CLI user has public/private keys at ~/.ssh/id_rsa.pub
      def boot_aws_inception_vm
        say "" # glowing whitespace

        public_key_path, private_key_path = local_ssh_key_paths
        unless settings["inception"] && settings["inception"]["server_id"]
          username = "ubuntu"
          size = "m1.small"
          say "Provisioning #{size} for inception VM..."
          server = fog_compute.servers.bootstrap({
            :public_key_path => public_key_path,
            :private_key_path => private_key_path,
            :flavor_id => size,
            :bits => 64,
            :username => "ubuntu"
          })
          unless server
            error "Something mysteriously cloudy happened and fog could not provision a VM. Please check your limits."
          end

          settings["inception"] = {}
          settings["inception"]["server_id"] = server.id
          settings["inception"]["username"] = username
          save_settings!
        end

        server ||= fog_compute.servers.get(settings["inception"]["server_id"])

        unless settings["inception"]["ip_address"]
          say "Provisioning IP address for inception VM..."
          ip_address = acquire_ip_address
          associate_ip_address_with_server(ip_address, server)
          host = server.dns_name

          settings["inception"]["ip_address"] = ip_address
          save_settings!
        end

        unless settings["inception"]["disk_size"]
          disk_size = DEFAULT_INCEPTION_VOLUME_SIZE # Gb
          device = "/dev/sdi"
          provision_and_mount_volume(server, disk_size, device)

          settings["inception"]["disk_size"] = disk_size
          settings["inception"]["disk_device"] = device
          save_settings!
        end

        # settings["inception"]["host"] is used externally to determine
        # if an inception VM has been assigned already; so we leave it
        # until last in this method to set this setting.
        # This way we can always rerun the CLI and rerun this method
        # and idempotently get an inception VM
        unless settings["inception"]["host"]
          settings["inception"]["host"] = server.dns_name
          save_settings!
        end

        confirm "Inception VM has been created"
        display_inception_ssh_access
      end

      # Provisions an OpenStack m1.small VM as the inception VM
      # Updates settings.inception.host/username
      #
      # NOTE: if any stage fails, when the CLI is re-run
      # and "create new server" is selected again, the process should
      # complete
      #
      # Assumes that local CLI user has public/private keys at ~/.ssh/id_rsa.pub
      def boot_openstack_inception_vm
        say "" # glowing whitespace

        public_key_path, private_key_path = local_ssh_key_paths

        # make sure we've a fog key pair
        key_pair_name = Fog.respond_to?(:credential) && Fog.credential || :default
        unless key_pair = fog_compute.key_pairs.get("fog_#{key_pair_name}")
          say "creating key pair fog_#{key_pair_name}..."
          public_key = File.open(public_key_path, 'rb') { |f| f.read }
          key_pair = fog_compute.key_pairs.create(
            :name => "fog_#{key_pair_name}",
            :public_key => public_key
          )
        end
        confirm "Using key pair #{key_pair.name} for Inception VM"

        unless settings["inception"] && settings["inception"]["server_id"]
          username = "ubuntu"
          say "Provisioning server for inception VM..."
          settings["inception"] = {}

          # Select OpenStack flavor
          unless settings["inception"]["flavor_id"]
            say ""
            hl.choose do |menu|
              menu.prompt = "Choose OpenStack flavor:  "
              fog_compute.flavors.each do |flavor|
                menu.choice(flavor.name) do
                  settings["inception"]["flavor_id"] = flavor.id
                  save_settings!
                end
              end
            end
          end

          # Select OpenStack image
          unless settings["inception"]["image_id"]
            say ""
            hl.choose do |menu|
              menu.prompt = "Choose OpenStack image (Ubuntu):  "
              fog_compute.images.each do |image|
                menu.choice(image.name) do
                  settings["inception"]["image_id"] = image.id
                  save_settings!
                end
              end
            end
          end

          # Boot OpenStack server
          server = fog_compute.servers.create(
            :name => "Inception VM",
            :key_name => key_pair.name,
            :public_key_path => public_key_path,
            :private_key_path => private_key_path,
            :flavor_ref => settings["inception"]["flavor_id"],
            :image_ref => settings["inception"]["image_id"],
            :username => username
          )
          unless server
            error "Something mysteriously cloudy happened and fog could not provision a VM. Please check your limits."
          end
          server.wait_for { ready? }

          settings["inception"]["server_id"] = server.id
          settings["inception"]["username"] = username
          save_settings!
        end

        server ||= fog_compute.servers.get(settings["inception"]["server_id"])

        unless settings["inception"]["ip_address"]
          say "Provisioning IP address for inception VM..."
          ip_address = acquire_ip_address
          associate_ip_address_with_server(ip_address, server)

          settings["inception"]["ip_address"] = ip_address
          save_settings!
        end

        unless settings["inception"]["disk_size"]
          disk_size = DEFAULT_INCEPTION_VOLUME_SIZE # Gb
          device = "/dev/vdc"
          provision_and_mount_volume(server, disk_size, device)

          settings["inception"]["disk_size"] = disk_size
          settings["inception"]["disk_device"] = device
          save_settings!

          # TODO use provision_and_mount_volume
          
          disk_size = 16 # Gb
          va = fog_compute.get_server_volumes(server.id).body['volumeAttachments']
          unless vol = va.find { |v| v["device"] == "/dev/vdc" }
            say "Provisioning #{disk_size}Gb persistent disk for inception VM..."
            volume = fog_compute.volumes.create(:name => "Inception Disk",
                                                :description => "",
                                                :size => disk_size,
                                                :availability_zone => server.availability_zone)
            volume.wait_for { volume.status == 'available' }
            volume.attach(server.id, "/dev/vdc")
            volume.wait_for { volume.status == 'in-use' }
          end

          # Format and mount the volume
          # TODO: Hack
          unless server.public_ip_address
            server.addresses["public"] = [settings["inception"]["ip_address"]]
          end
          unless server.public_key_path
            server.public_key_path = public_key_path
          end
          unless server.private_key_path
            server.private_key_path = private_key_path
          end
          server.username = settings["inception"]["username"]
          server.sshable?

          say "Mounting persistent disk as volume on inception VM..."
          # TODO if any of these ssh calls fail; retry
          server.ssh(['sudo mkfs.ext4 /dev/vdc -F'])
          server.ssh(['sudo mkdir -p /var/vcap/store'])
          server.ssh(['sudo mount /dev/vdc /var/vcap/store'])

          settings["inception"]["disk_size"] = disk_size
          save_settings!
        end

        # settings["inception"]["host"] is used externally to determine
        # if an inception VM has been assigned already; so we leave it
        # until last in this method to set this setting.
        # This way we can always rerun the CLI and rerun this method
        # and idempotently get an inception VM
        unless settings["inception"]["host"]
          settings["inception"]["host"] = settings["inception"]["ip_address"]
          save_settings!
        end

        confirm "Inception VM has been created"
        display_inception_ssh_access
      end

      # Provision or provide an IP address to use
      # For AWS, it will dynamically provision an elastic IP
      # For OpenStack, it will dynamically provision a floating IP
      def acquire_ip_address
        unless public_ip = provider.provision_public_ip_address
          say "Unable to acquire a public IP. Please check your account for capacity or service issues.".red
          exit 1
        end
        public_ip
      end

      def associate_ip_address_with_server(ip_address, server)
        if aws?
          address = fog_compute.addresses.get(ip_address)
        elsif openstack?
          address = fog_compute.addresses.find { |a| a.ip == ip_address }
        else
          raise "implement #associate_ip_address_with_server for #{settings.fog_credentials.provider}"
        end
        address.server = server
        server.reload
      end

      # Provision a volume for a specific device (unless already provisioned)
      # Request that the +server+ mount the volume at the +device+ location.
      #
      # Requires that we can SSH into +server+.
      def provision_and_mount_volume(server, disk_size, device)
        unless volume = server.volumes.all.find {|v| v.device == device}
          say "Provisioning #{disk_size}Gb persistent disk for inception VM..."
          volume = fog_compute.volumes.create(
            size: disk_size,
            name: "Inception Disk",
            description: '',
            device: "/dev/sdi",
            availability_zone: server.availability_zone)
          # TODO: the following works in fog 1.9.0+ (but which has a bug in bootstrap)
          # https://github.com/fog/fog/issues/1516
          #
          # volume.wait_for { volume.status == 'available' }
          # volume.attach(server.id, "/dev/vdc")
          # volume.wait_for { volume.status == 'in-use' }
          #
          # Instead, using:
          volume.server = server
        end

        # Format and mount the volume
        say "Mounting persistent disk as volume on inception VM..."
        disk_mounted = false
        until disk_mounted
          begin
            # TODO catch Errno::ETIMEDOUT and re-run ssh commands
            server.ssh(["sudo mkfs.ext4 #{device} -F"]) 
            server.ssh(["sudo mkdir -p /var/vcap/store"])
            server.ssh(["sudo mount #{device} /var/vcap/store"])
            disk_mounted = true
          rescue Errno::ETIMEDOUT => e
            say "Timeout error/warning mounting volume, retrying...", yellow
          end
        end
      end

      def display_inception_ssh_access
        _, private_key_path = local_ssh_key_paths
        say "SSH access: ssh -i #{private_key_path} #{settings["inception"]["username"]}@#{settings["inception"]["host"]}"
      end

      # Discover/create local passphrase-less SSH keys to allow
      # communication with Inception VM
      #
      # Returns [public_key_path, private_key_path]
      def local_ssh_key_paths
        unless settings["local"] && settings["local"]["private_key_path"]
          settings["local"] = {}
          public_key_path = File.expand_path("~/.ssh/id_rsa.pub")
          private_key_path = File.expand_path("~/.ssh/id_rsa")
          raise "Please create public keys at ~/.ssh/id_rsa.pub or use --private-key flag" unless File.exists?(public_key_path)

          settings["local"]["public_key_path"] = public_key_path
          settings["local"]["private_key_path"] = private_key_path
          save_settings!
        end
        [settings.local.public_key_path, settings.local.private_key_path]
      end

      def aws?
        settings.fog_credentials.provider == "AWS"
      end

      def openstack?
        settings.fog_credentials.provider == "OpenStack"
      end

      def prompt_for_bosh_credentials
        prompt = hl
        say "Please enter a user/password for the BOSH that will be created."
        settings[:bosh_username] = prompt.ask("BOSH username: ") { |q| q.default = `whoami`.strip }
        settings[:bosh_password] = prompt.ask("BOSH password: ") { |q| q.echo = "x" }
        save_settings!
      end

      # Returns the latest micro-bosh stemcell
      # for the target provider (aws, vsphere, openstack)
      def micro_bosh_stemcell_name
        @micro_bosh_stemcell_name ||= begin
          provider = settings.bosh_provider.downcase # aws, vsphere, openstack
          stemcell_filter_tags = ['micro', provider]
          if openstack?
            # FIXME remove this if when openstack has its first stable
          else
            if settings["micro_bosh_stemcell_type"] == "stable"
              stemcell_filter_tags << "stable" # latest stable micro-bosh stemcell by default
            end
          end
          tags = stemcell_filter_tags.join(",")
          bosh_stemcells_cmd = "bosh public stemcells --tags #{tags}"
          say "Locating micro-bosh stemcell, running '#{bosh_stemcells_cmd}'..."
          #
          # The +bosh_stemcells_cmd+ has an output that looks like:
          # +-----------------------------------+--------------------+
          # | Name                              | Tags               |
          # +-----------------------------------+--------------------+
          # | micro-bosh-stemcell-aws-0.6.4.tgz | aws, micro, stable |
          # | micro-bosh-stemcell-aws-0.7.0.tgz | aws, micro, test   |
          # +-----------------------------------+--------------------+
          #
          # So to get the latest version for the filter tags,
          # get the Name field, reverse sort, and return the first item
          `#{bosh_stemcells_cmd} | grep micro | awk '{ print $2 }' | sort -r | head -n 1`.strip
        end
      end

      def provider_name
        settings.bosh_provider
      end

      # a helper object for the target BOSH provider
      def provider
        @provider ||= Bosh::Providers.for_bosh_provider_name(settings.bosh_provider, fog_compute)
      end

      def cyan; "\033[36m" end
      def clear; "\033[0m" end
      def bold; "\033[1m" end
      def red; "\033[31m" end
      def green; "\033[32m" end
      def yellow; "\033[33m" end

      # Helper to access HighLine for ask & menu prompts
      def hl
        @hl ||= HighLine.new
      end
    end
  end
end