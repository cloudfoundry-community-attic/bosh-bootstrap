class Bosh::Bootstrap::Commander::LocalServer
  # Execute the +Command+ objects, in sequential order
  # upon the local server
  # +commands+ is a +Commands+ container
  def run(commands)
    commands.commands.each do |command|
      puts command.full_present_tense
      puts command.full_past_tense
    end
  end
end