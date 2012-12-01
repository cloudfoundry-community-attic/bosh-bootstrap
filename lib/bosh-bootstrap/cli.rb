require "thor"
require "highline"
require "settingslogic"
require "fileutils"
require "fog"

module Bosh::Bootstrap
  class Cli < Thor
    include Thor::Actions

    attr_reader :fog_credentials
    attr_reader :server

    desc "deploy", "Bootstrap bosh, using a remote server as inception VM"
    method_option :fog, :type => :string, :desc => "fog config file (default: ~/.fog)"
    method_option :"upgrade-deps", :type => :boolean, :desc => "Force upgrade dependencies, packages & gems"
    def deploy
      load_options # from method_options above

      stage_1_choose_infrastructure_provider
      stage_2_bosh_configuration
      stage_3_create_allocate_inception_vm
      stage_4_prepare_inception_vm
      stage_5_deploy_micro_bosh
    end

    no_tasks do
      def stage_1_choose_infrastructure_provider
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
      
      def stage_2_bosh_configuration
        header "Stage 2: BOSH configuration"
        unless settings[:bosh_name]
          provider, region = settings.bosh_provider, settings.region_code
          if region
            default_name = "microbosh_#{provider}_#{region}".gsub(/\W+/, '_')
          else
            default_name = "microbosh_#{provider}".gsub(/\W+/, '_')
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

      def stage_3_create_allocate_inception_vm
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
        if settings["inception"]["host"]
          @server = Commander::RemoteServer.new(settings.inception.host)
          confirm "Using inception VM #{settings.inception.username}@#{settings.inception.host}"
        else
          @server = Commander::LocalServer.new
          confirm "Using this server as the inception VM"
        end

        unless server.run(Bosh::Bootstrap::Stages::StageValidateInceptionVm.new(settings).commands)
          error "Failed to complete Stage 3: Create/Allocate the Inception VM"
        end
        # If successfully validate inception VM, then save those settings.
        save_settings!
      end

      def stage_4_prepare_inception_vm
        header "Stage 4: Preparing the Inception VM"
        unless server.run(Bosh::Bootstrap::Stages::StagePrepareInceptionVm.new(settings).commands)
          error "Failed to complete Stage 4: Preparing the Inception VM"
        end
        # Settings are updated by this stage
        # it generates a salted password from settings.bosh.password
        # and stores it in settings.bosh.salted_password
        save_settings!
      end

      def stage_5_deploy_micro_bosh
        header "Stage 5: Deploying micro BOSH"
        unless server.run(Bosh::Bootstrap::Stages::MicroBoshDeploy.new(settings).commands)
          error "Failed to complete Stage 5: Deploying micro BOSH"
        end

        if settings[:bosh_deployed]
          confirm "Successfully updated micro BOSH"
        else
          confirm "Successfully created micro BOSH"
        end
        say "Locally targeting and login to new BOSH..."
        puts `bosh target #{settings.bosh.ip_address}`
        puts `bosh login #{settings.bosh_username} #{settings.bosh_password}`

        settings[:bosh_deployed] = true
        save_settings!

        confirm "You are now targeting and logged in to your BOSH"
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
        @settings = nil # force to reload & recreate helper methods
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
          # props[:default_key_name] = "microbosh"  - via +create_aws_key_pair+
          # props[:ec2_private_key] = "/home/vcap/.ssh/microbosh.pem" - via +create_aws_key_pair+
          # props[:default_security_groups] = ["microbosh"], - via +create_aws_security_group+
        elsif openstack?
          settings[:bosh_cloud_properties] = {}
          settings[:bosh_cloud_properties][:openstack] = {}
          props = settings[:bosh_cloud_properties][:openstack]
          props[:openstack_username] = settings.fog_credentials.openstack_username
          props[:openstack_api_key] = settings.fog_credentials.openstack_api_key
          props[:openstack_tenant] = settings.fog_credentials.openstack_tenant
          props[:openstack_auth_url] = settings.fog_credentials.openstack_auth_url
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
          settings[:region_code] = nil
          false
        end
      end

      def choose_aws_region
        hl.choose do |menu|
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

      # Creates a security group.
      def create_security_group(security_group_name)
        if aws?
          create_aws_security_group(security_group_name)
        elsif openstack?
          create_openstack_security_group(security_group_name)
        else
          raise "implement #create_security_group for #{settings.fog_credentials.provider}"
        end
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
            say "opened port #{port} in security group #{security_group_name}"
          end
          save_settings!
        else
          error "AWS security group '#{security_group_name}' already exists. Rename BOSH or delete old security group manually and re-run CLI."
        end
      end

      # Creates a OpenStack security group.
      # Also sets up the bosh_cloud_properties for the remote server
      #
      # Adds settings:
      # * bosh_security_group.name
      # * bosh_security_group.ports
      # * bosh_cloud_properties.openstack.default_security_groups
      def create_openstack_security_group(security_group_name)
        unless fog_compute.security_groups.find { |sg| sg.name == security_group_name }
          # Hack until fog 1.9 is released
          # sg = fog_compute.security_groups.create(:name => security_group_name, description: "microbosh")
          data = fog_compute.create_security_group(security_group_name, "microbosh")
          sg = fog_compute.security_groups.get(data.body['security_group']['id'])
          settings.bosh_cloud_properties.openstack[:default_security_groups] = [security_group_name]
          settings[:bosh_security_group] = {}
          settings[:bosh_security_group][:name] = security_group_name
          settings[:bosh_security_group][:ports] = {}
          settings[:bosh_security_group][:ports][:ssh_access] = 22
          settings[:bosh_security_group][:ports][:message_bus] = 6868
          settings[:bosh_security_group][:ports][:bosh_director] = 25555
          settings[:bosh_security_group][:ports][:openstack_registry] = 25888
          settings.bosh_security_group.ports.values.each do |port|
            sg.create_security_group_rule(port, port)
            say "opened port #{port} in security group #{security_group_name}"
          end
          save_settings!
        else
          error "OpenStack security group '#{security_group_name}' already exists. Rename BOSH or delete old security group manually and re-run CLI."
        end
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

        public_key = File.expand_path("~/.ssh/id_rsa.pub")
        private_key = File.expand_path("~/.ssh/id_rsa")
        raise "Please create public keys at ~/.ssh/id_rsa.pub" unless File.exists?(public_key)
        unless settings["inception"] && settings["inception"]["server_id"]
          username = "ubuntu"
          size = "m1.small"
          say "Provisioning #{size} for inception VM..."
          server = fog_compute.servers.bootstrap({
            :public_key_path => public_key,
            :private_key_path => private_key,
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

        unless settings["inception"]["ip_address"]
          server ||= fog_compute.servers.get(settings.inception.server_id)

          say "Provisioning IP address for inception VM..."
          ip_address = provision_elastic_ip_address # returns IP as a String
          address = fog_compute.addresses.get(ip_address)
          address.server = server
          server.reload
          host = server.dns_name

          settings["inception"]["ip_address"] = ip_address
          save_settings!
        end

        unless settings["inception"]["disk_size"]
          server ||= fog_compute.servers.get(settings.inception.server_id)

          disk_size = 16 # Gb
          unless volume = server.volumes.all.find {|v| v.device == "/dev/sdi"}
            say "Provisioning #{disk_size}Gb persistent disk for inception VM..."
            volume = fog_compute.volumes.create(:size => disk_size, :device => "/dev/sdi", :availability_zone => server.availability_zone)
            volume.server = server
          end

          # Format and mount the volume
          say "Mounting persistent disk as volume on inception VM..."
          server.ssh(['sudo mkfs.ext4 /dev/sdi -F']) 
          server.ssh(['sudo mkdir -p /var/vcap/store'])
          server.ssh(['sudo mount /dev/sdi /var/vcap/store'])

          settings["inception"]["disk_size"] = disk_size
          save_settings!
        end

        # settings["inception"]["host"] is used externally to determine
        # if an inception VM has been assigned already; so we leave it
        # until last in this method to set this setting.
        # This way we can always rerun the CLI and rerun this method
        # and idempotently get an inception VM
        unless settings["inception"]["host"]
          server ||= fog_compute.servers.get(settings.inception.server_id)
          settings["inception"]["host"] = server.dns_name
          save_settings!
        end

        confirm "Inception VM has been created"
        say "SSH access: ssh #{settings["inception"]["username"]}@#{settings["inception"]["host"]}"
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

        # make sure we've a fog key pair
        public_key_file = File.expand_path("~/.ssh/id_rsa.pub")
        private_key_file = File.expand_path("~/.ssh/id_rsa")
        raise "Please create public keys at ~/.ssh/id_rsa.pub" unless File.exists?(public_key_file)
        key_pair_name = Fog.respond_to?(:credential) && Fog.credential || :default
        unless key_pair = fog_compute.key_pairs.get("fog_#{key_pair_name}")
          #say "creating key pair fog_#{key_pair_name}..."
          public_key = File.open(public_key_file, 'rb') { |f| f.read }
          key_pair = fog_compute.key_pairs.create(
            :name => "fog_#{key_pair_name}",
            :public_key => public_key
          )
        end

        # make sure port 22 is open in the default security group
        security_group = fog_compute.security_groups.find { |sg| sg.name == 'default' }
        authorized = security_group.rules.detect do |ip_permission|
            ip_permission['ip_range'].first && ip_permission['ip_range']['cidr'] == '0.0.0.0/0' &&
            ip_permission['from_port'] == 22 &&
            ip_permission['ip_protocol'] == 'tcp' &&
            ip_permission['to_port'] == 22
        end
        unless authorized
          security_group.create_security_group_rule(22, 22)
        end

        unless settings["inception"] && settings["inception"]["server_id"]
          username = "ubuntu"
          size = "m1.small"
          say "Provisioning #{size} for inception VM..."
          flavor = fog_compute.flavors.find { |f| f.name == size }
          image = fog_compute.images.find { |i| i.name == 'lucid-server-cloudimg-amd64' }
          server = fog_compute.servers.create(
            :name => "Inception VM",
            :key_name => key_pair.name,
            :public_key_path => public_key_file,
            :private_key_path => private_key_file,
            :flavor_ref => flavor.id,
            :image_ref => image.id,
            :username => username
          )
          unless server
            error "Something mysteriously cloudy happened and fog could not provision a VM. Please check your limits."
          end
          server.wait_for { ready? }

          settings["inception"] = {}
          settings["inception"]["server_id"] = server.id
          settings["inception"]["username"] = username
          save_settings!
        end

        unless settings["inception"]["ip_address"]
          server ||= fog_compute.servers.get(settings.inception.server_id)

          say "Provisioning IP address for inception VM..."
          ip_address = provision_floating_ip_address # returns IP as a String
          address = fog_compute.addresses.find { |a| a.ip == ip_address }
          address.server = server
          server.reload
          host = ip_address
          # TODO: Hack
          server.addresses["public"] = [{"version" => 4, "addr" => ip_address}]

          settings["inception"]["ip_address"] = ip_address
          save_settings!
        end

        unless settings["inception"]["disk_size"]
          server ||= fog_compute.servers.get(settings.inception.server_id)

          disk_size = 16 # Gb
          unless volume = server.volumes.all.find {|v| v.device == "/dev/sdi"}
            say "Provisioning #{disk_size}Gb persistent disk for inception VM..."
            volume = fog_compute.volumes.create(:name => "Inception Disk",
                                                :description => "",
                                                :size => disk_size,
                                                :device => "/dev/sdi",
                                                :availability_zone => server.availability_zone)
            volume.server = server
          end

          # Format and mount the volume
          say "Mounting persistent disk as volume on inception VM..."
          server.ssh(['sudo mkfs.ext4 /dev/sdi -F'])
          server.ssh(['sudo mkdir -p /var/vcap/store'])
          server.ssh(['sudo mount /dev/sdi /var/vcap/store'])

          settings["inception"]["disk_size"] = disk_size
          save_settings!
        end

        # settings["inception"]["host"] is used externally to determine
        # if an inception VM has been assigned already; so we leave it
        # until last in this method to set this setting.
        # This way we can always rerun the CLI and rerun this method
        # and idempotently get an inception VM
        unless settings["inception"]["host"]
          server ||= fog_compute.servers.get(settings.inception.server_id)
          settings["inception"]["host"] = server.dns_name
          save_settings!
        end

        confirm "Inception VM has been created"
        say "SSH access: ssh #{settings["inception"]["username"]}@#{settings["inception"]["host"]}"
      end

      # Provision or provide an IP address to use
      # For AWS, it will dynamically provision an elastic IP
      # For OpenStack, it will dynamically provision a floating IP
      # For other providers, it may opt to prompt for a static IP
      # to use.
      def acquire_ip_address
        if aws?
          provision_elastic_ip_address
        elsif openstack?
          provision_floating_ip_address
        else
          hl.ask("What static IP to use for micro BOSH?  ")
        end
      end

      # using fog, provision an elastic IP address
      # TODO what is the error raised if no IPs available?
      # returns an IP address as a string, e.g. "1.2.3.4"
      def provision_elastic_ip_address
        address = fog_compute.addresses.create
        address.public_ip
      end

      # using fog, provision a floating IP address
      # TODO what is the error raised if no IPs available?
      # returns an IP address as a string, e.g. "1.2.3.4"
      def provision_floating_ip_address
        address = fog_compute.addresses.create
        address.ip
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
          if File.exists?(fog_config_path)
            say "Found infrastructure API credentials at #{fog_config_path} (override with --fog)"
            YAML.load_file(fog_config_path)
          else
            say "No existing #{fog_config_path} fog configuration file", :yellow
            {}
          end
        end
      end

      def fog_config_path
        settings.fog_path
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
        settings[:bosh_username] = prompt.ask("BOSH username: ")
        settings[:bosh_password] = prompt.ask("BOSH password: ") { |q| q.echo = "x" }
        save_settings!
      end

      # Returns the latest micro-bosh stemcell
      # for the target provider (aws, vsphere, openstack)
      def micro_bosh_stemcell_name
        @micro_bosh_stemcell_name ||= begin
          provider = settings.bosh_provider.downcase # aws, vsphere, openstack
          if openstack?
            scope = ",test" # TODO: OpenStack stemcell
          else
            scope = ",stable" # latest stable micro-bosh stemcell by default
          end
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

      # Helper to access HighLine for ask & menu prompts
      def hl
        @hl ||= HighLine.new
      end
    end
  end
end