require "json" # for inline hashes within YAML

module Bosh::Bootstrap::Stages
  class MicroBoshDelete
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    def commands
      @commands ||= Bosh::Bootstrap::Commander::Commands.new do |server|
        server.delete "micro bosh", script("bosh_micro_delete",
                      "BOSH_NAME" => settings.bosh_name)
      end
    end

    private
    def stage_name
      "stage_micro_bosh_delete"
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
            "#{cloud_plugin.downcase}_registry" => { "address" => ipaddress }
          }
        }
      }.to_yaml.gsub(" !ruby/hash:Settingslogic", "")
    end
  end
end
