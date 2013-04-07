require "json" # for inline hashes within YAML

module Bosh::Bootstrap::Stages
  class SaltedPassword
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    def commands
      @commands ||= Bosh::Bootstrap::Commander::Commands.new do |server|
        # use inception VM to generate a salted password (local machine may not have mkpasswd)
        server.capture_value "salted password", script("convert_salted_password", "PASSWORD" => settings.bosh.password),
          :settings => settings, :save_output_to_settings_key => "bosh.salted_password"
      end
    end

    def stage_name
      "stage_salted_password"
    end

    # Loads local script
    # If +variables+, then injects KEY=VALUE environment
    # variables into bash scripts.
    def script(segment_name, variables={})
      path = File.expand_path("../#{stage_name}/#{segment_name}", __FILE__)
      if File.exist?(path)
        script = File.read(path)
        if variables.keys.size > 0
          env_variables = variables.reject { |var| var.is_a?(Symbol) }

          # inject variables into script if its bash script
          inline_variables = "#!/usr/bin/env bash\n\n"
          env_variables.each { |name, value| inline_variables << "#{name}='#{value}'\n" }
          script.gsub!("#!/usr/bin/env bash", inline_variables)

          # inject variables into script if its ruby script
          inline_variables = "#!/usr/bin/env ruby\n\n"
          env_variables.each { |name, value| inline_variables << "ENV['#{name}'] = '#{value}'\n" }
          script.gsub!("#!/usr/bin/env ruby", inline_variables)
        end
        script
      else
        Thor::Base.shell.new.say_status "error", "Missing script lib/bosh-bootstrap/stages/#{stage_name}/#{segment_name}", :red
        exit 1
      end
    end

  end
end
