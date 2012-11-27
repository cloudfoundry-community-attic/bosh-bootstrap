class Bosh::Bootstrap::Commander::Commands
  def initialize(&block)
    @commands = []
    yield self
  end

  def assign(description, script)
    @commands << Command.new(
      "assign", description, script,
      "assigning #{description}", "assigned #{description}")
  end

  def create(description, script)
    @commands << Command.new(
      "create", description, script,
      "creating #{description}", "created #{description}")
  end

  def download(description, script)
    @commands << Command.new(
      "download", description, script,
      "downloading #{description}", "downloaded #{description}")
  end

  def install(description, script)
    @commands << Command.new(
      "install", description, script,
      "installing #{description}", "installed #{description}")
  end

  def provision(description, script)
    @commands << Command.new(
      "provision", description, script,
      "provisioning #{description}", "provisioned #{description}")
  end

  def store(description, script)
    @commands << Command.new(
      "store", description, script,
      "storing #{description}", "stored #{description}")
  end

  # catch-all for commands with generic active/past tense phrases
  def method_missing(command, *args, &blk)
    description, script = args[0..1]
    @commands << Command.new(command.to_s, description, script)
  end
end
