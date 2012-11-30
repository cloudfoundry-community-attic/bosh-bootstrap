module Bosh::Bootstrap::Commander
  class Commands
    attr_reader :commands

    def initialize(&block)
      @commands = []
      yield self
    end

    def upload_file(target_path, file_contents)
      @commands << UploadCommand.new(target_path, file_contents)
    end

    #
    # Generic remote script commands with custom phrases
    #

    def assign(description, script, options={})
      @commands << RemoteScriptCommand.new(
        "assign", description, script,
        "assigning #{description}", "assigned #{description}", options)
    end

    # Runs a script on target server, and stores the (stripped) STDOUT into
    # settings.
    # 
    # Usage:
    # server.capture_value "salted password", script("convert_salted_password", "PASSWORD" => settings.bosh.password),
    #   :settings => "bosh.salted_password"
    #
    # Would store the returned STDOUT into settings[:bosh][:salted_password]
    def capture_value(description, script, options)
      @commands << RemoteScriptCommand.new(
        "capture value", description, script,
        "captures value of #{description}", "captured value of #{description}", options)
    end

    def create(description, script, options={})
      @commands << RemoteScriptCommand.new(
        "create", description, script,
        "creating #{description}", "created #{description}", options)
    end

    def download(description, script, options={})
      @commands << RemoteScriptCommand.new(
        "download", description, script,
        "downloading #{description}", "downloaded #{description}", options)
    end

    def install(description, script, options={})
      @commands << RemoteScriptCommand.new(
        "install", description, script,
        "installing #{description}", "installed #{description}", options)
    end

    def provision(description, script, options={})
      @commands << RemoteScriptCommand.new(
        "provision", description, script,
        "provisioning #{description}", "provisioned #{description}", options)
    end

    def store(description, script, options={})
      @commands << RemoteScriptCommand.new(
        "store", description, script,
        "storing #{description}", "stored #{description}", options)
    end

    def validate(description, script, options={})
      @commands << RemoteScriptCommand.new(
        "validate", description, script,
        "validating #{description}", "validated #{description}", options)
    end

    # catch-all for commands with generic active/past tense phrases
    def method_missing(command, *args, &blk)
      description, script = args[0..1]
      @commands << RemoteScriptCommand.new(command.to_s, description, script)
    end
  end
end