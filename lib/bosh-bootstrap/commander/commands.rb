module Bosh::Bootstrap::Commander
  class Commands
    attr_reader :commands

    def initialize(&block)
      @commands = []
      yield self
    end

    def upload_file(file_contents, target_location)
      @commands << UploadCommand.new(file_contents, target_location)
    end

    #
    # Generic remote script commands with custom phrases
    #

    def assign(description, script)
      @commands << RemoteScriptCommand.new(
        "assign", description, script,
        "assigning #{description}", "assigned #{description}")
    end

    def create(description, script)
      @commands << RemoteScriptCommand.new(
        "create", description, script,
        "creating #{description}", "created #{description}")
    end

    def download(description, script)
      @commands << RemoteScriptCommand.new(
        "download", description, script,
        "downloading #{description}", "downloaded #{description}")
    end

    def install(description, script)
      @commands << RemoteScriptCommand.new(
        "install", description, script,
        "installing #{description}", "installed #{description}")
    end

    def provision(description, script)
      @commands << RemoteScriptCommand.new(
        "provision", description, script,
        "provisioning #{description}", "provisioned #{description}")
    end

    def store(description, script)
      @commands << RemoteScriptCommand.new(
        "store", description, script,
        "storing #{description}", "stored #{description}")
    end

    def validate(description, script)
      @commands << RemoteScriptCommand.new(
        "validate", description, script,
        "validating #{description}", "validated #{description}")
    end

    # catch-all for commands with generic active/past tense phrases
    def method_missing(command, *args, &blk)
      description, script = args[0..1]
      @commands << RemoteScriptCommand.new(command.to_s, description, script)
    end
  end
end