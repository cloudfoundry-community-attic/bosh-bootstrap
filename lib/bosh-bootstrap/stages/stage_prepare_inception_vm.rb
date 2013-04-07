module Bosh::Bootstrap::Stages
  class StagePrepareInceptionVm
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    def commands
      @commands ||= Bosh::Bootstrap::Commander::Commands.new do |server|
        # using inception VM username login, create a vcap user with same authorizations
        server.create "vcap user", script("create_vcap_user",
          "ORIGUSER" => settings.inception.username),
          ssh_username: settings.inception.username, run_as_root: true
        # install base Ubuntu packages used for bosh micro deployer
        server.install "base packages", script("install_base_packages"), run_as_root: true
        server.configure "git", script("configure_git",
          "GIT_USER_NAME" => settings["git"]["name"],
          "GIT_USER_EMAIL" => settings["git"]["email"])
        server.install "ruby 1.9.3", script("install_ruby", "UPGRADE" => settings[:upgrade_deps]),
          run_as_root: true
        server.install "useful ruby gems", script("install_useful_gems", "UPGRADE" => settings[:upgrade_deps])
        server.install "hub", script("install_hub")
        server.install "bosh", script("install_bosh",
          "UPGRADE" => settings[:upgrade_deps],
          "INSTALL_BOSH_FROM_SOURCE" => settings["bosh_git_source"] || "")
        server.install "bosh plugins", script("install_bosh_plugins", "UPGRADE" => settings[:upgrade_deps])

        server.validate "bosh deployer", script("validate_bosh_deployer")
      end
    end

    private
    def stage_name
      "stage_prepare_inception_vm"
    end

    # Loads local script
    # If +variables+, then injects KEY=VALUE environment
    # variables into bash scripts.
    def script(segment_name, variables={})
      path = File.expand_path("../#{stage_name}/#{segment_name}", __FILE__)
      if File.exist?(path)
        script = File.read(path)
        if variables.keys.size > 0
          inline_variables = "#!/usr/bin/env bash\n\n"
          env_variables = variables.reject { |var| var.is_a?(Symbol) }
          env_variables.each { |name, value| inline_variables << "#{name}='#{value}'\n" }
          script.gsub!("#!/usr/bin/env bash", inline_variables)
        end
        script
      else
        Thor::Base.shell.new.say_status "error", "Missing script lib/bosh-bootstrap/stages/#{stage_name}/#{segment_name}", :red
        exit 1
      end
    end
  end
end
