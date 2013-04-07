require "json" # for inline hashes within YAML

module Bosh::Bootstrap::Stages
  class SetupNewBosh
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    def commands
      @commands ||= Bosh::Bootstrap::Commander::Commands.new do |server|
        server.setup "bosh user", script("setup_bosh_user",
                      "BOSH_NAME" => settings.bosh_name,
                      "BOSH_HOST" => settings.bosh.ip_address,
                      "BOSH_USERNAME" => settings.bosh_username,
                      "BOSH_PASSWORD" => settings.bosh_password),
          run_as_root: true
        server.cleanup "permissions", script("cleanup_permissions"),
          run_as_root: true
      end
    end

    private
    def stage_name
      "stage_setup_new_bosh"
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
  end
end
