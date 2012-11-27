class Bosh::Bootstrap::Commander::Commands
  def initialize(&block)
    @commands = []
    yield self
  end

  def create(description, script)
    @commands << Command.new(
      "create", description, script,
      "creating #{description}", "created #{description}")
  end

  def install(description, script)
    @commands << Command.new(
      "install", description, script,
      "installing #{description}", "installed #{description}")
  end

  # catch-all for commands with generic active/past tense phrases
  def method_missing(command, *args, &blk)
    description, script = args[0..1]
    @commands << Command.new(command.to_s, description, script)
  end
end
