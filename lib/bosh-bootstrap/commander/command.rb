# A single command/script to be run on a local/remote server
# For the display, it has an active ("installing") and 
# past tense ("installed") verb and a noub/description ("packages")
module Bosh::Bootstrap::Commander
  class Command
    attr_reader :command       # verb e.g. "install"
    attr_reader :description   # noun phrase, e.g. "packages"

    attr_reader :full_present_tense  # e.g. "installing packages"
    attr_reader :full_past_tense    # e.g. "installed packages"
  
    def initialize(command, description, full_present_tense=nil, full_past_tense=nil)
      @command            = command
      @description        = description
      @full_present_tense = full_present_tense || "#{command} #{description}"
      @full_past_tense    = full_past_tense || "#{command} #{description}"
    end

    # Invoke this command (subclass) to call back upon
    # +server+ to perform a server helper
    def perform(server)
      raise "please implement this method to call back upon `server`"
    end
  end
end