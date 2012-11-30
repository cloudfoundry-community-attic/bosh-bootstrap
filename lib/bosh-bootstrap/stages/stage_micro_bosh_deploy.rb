require "json" # for inline hashes within YAML

module Bosh::Bootstrap::Stages
  class MicroBoshDeploy
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    # TODO "aws_us_east_1" should come from settings.bosh_name
    def commands
      settings[:bosh_name] ||= "unnamed_bosh"

      @commands ||= Bosh::Bootstrap::Commander::Commands.new do |server|
        server.download "micro-bosh stemcell", script("download_micro_bosh_stemcell",
                      "MICRO_BOSH_STEMCELL_NAME" => settings.micro_bosh_stemcell_name)
        server.upload_file \
                      "/var/vcap/store/microboshes/deployments/#{settings.bosh_name}/micro_bosh.yml",
                      micro_bosh_manifest
        server.install "key pair for user", script("install_key_pair_for_user",
                      "PRIVATE_KEY" => settings.bosh_key_pair.private_key,
                      "KEY_PAIR_NAME" => settings.bosh_key_pair.name)
        server.deploy "micro bosh", script("bosh_micro_deploy",
                      "BOSH_NAME" => settings.bosh_name,
                      "MICRO_BOSH_STEMCELL_NAME" => settings.micro_bosh_stemcell_name,
                      "BOSH_USERNAME" => settings.bosh_username,
                      "BOSH_PASSWORD" => settings.bosh_password,
                      "BOSH_UPDATED_DEPLOY" => settings[:bosh_deployed] || "")
      end
    end

    private
    def stage_name
      "stage_micro_bosh_deploy"
    end

    # Loads local script
    # If +variables+, then injects KEY=VALUE environment
    # variables into bash scripts.
    def script(segment_name, variables={})
      path = File.expand_path("../#{stage_name}/#{segment_name}", __FILE__)
      if File.exist?(path)
        script = File.read(path)
        if variables.keys.size > 0
          # inject variables into script if its bash script
          inline_variables = "#!/usr/bin/env bash\n\n"
          variables.each { |name, value| inline_variables << "#{name}='#{value}'\n" }
          script.gsub!("#!/usr/bin/env bash", inline_variables)

          # inject variables into script if its ruby script
          inline_variables = "#!/usr/bin/env ruby\n\n"
          variables.each { |name, value| inline_variables << "ENV['#{name}'] = '#{value}'\n" }
          script.gsub!("#!/usr/bin/env ruby", inline_variables)
        end
        script
      else
        Thor::Base.shell.new.say_status "error", "Missing script lib/bosh-bootstrap/stages/#{stage_name}/#{segment_name}", :red
        exit 1
      end
    end

    def micro_bosh_manifest
      name                       = settings.bosh_name
      salted_password            = settings.bosh.salted_password
      ipaddress                  = settings.bosh.ip_address
      persistent_disk            = settings.bosh.persistent_disk
      resources_cloud_properties = settings.bosh_resources_cloud_properties
      cloud_plugin               = settings.bosh_provider

      # aws:
      #   access_key_id:     #{access_key}
      #   secret_access_key: #{secret_key}
      #   ec2_endpoint: ec2.#{region}.amazonaws.com
      #   default_key_name: #{key_name}
      #   default_security_groups: ["#{security_group}"]
      #   ec2_private_key: /home/vcap/.ssh/#{key_name}.pem
      cloud_properties = settings.bosh_cloud_properties

      {
        "name" => name,
        "env" => { "bosh" => {"password" => salted_password}},
        "logging" => { "level" => "DEBUG" },
        "network" => { "type" => "dynamic", "vip" => ipaddress },
        "resources" => {
          "persistent_disk" => persistent_disk,
          "cloud_properties" => resources_cloud_properties
        },
        "cloud" => {
          "plugin" => cloud_plugin,
          "properties" => cloud_properties
        },
        "apply_spec" => {
          "agent" => {
            "blobstore" => { "address" => ipaddress },
            "nats" => { "address" => ipaddress }
          },
          "properties" => {
            "aws_registry" => { "address" => ipaddress }
          }
        }
      }.to_yaml.gsub(" !ruby/hash:Settingslogic", "")
    end
  end
end
