# A single command/script to be run on a local/remote server
# For the display, it has an active ("installing") and 
# past tense ("installed") verb and a noub/description ("packages")
class Bosh::Bootstrap::Commander::Command
  attr_reader :command       # verb e.g. "install"
  attr_reader :description   # noun phrase, e.g. "packages"
  attr_reader :script

  attr_reader :full_active_tense  # e.g. "installing packages"
  attr_reader :full_past_tense    # e.g. "installed packages"
  
  def initialize(command, description, script, full_active_tense=nil, full_past_tense=nil)
    @command           = command
    @description       = description
    @full_active_tense = full_active_tense || "#{command} #{description}"
    @full_past_tense   = full_past_tense || "#{command} #{description}"
  end
end
