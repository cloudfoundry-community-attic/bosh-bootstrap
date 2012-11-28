# A single command/script to be run on a local/remote server
# For the display, it has an active ("installing") and 
# past tense ("installed") verb and a noub/description ("packages")
module Bosh::Bootstrap::Commander
  class RemoteScriptCommand < Command
    attr_reader :command       # verb e.g. "install"
    attr_reader :description   # noun phrase, e.g. "packages"
    attr_reader :script

    attr_reader :full_present_tense  # e.g. "installing packages"
    attr_reader :full_past_tense    # e.g. "installed packages"
  
    def initialize(command, description, script, full_present_tense=nil, full_past_tense=nil)
      super(command, description, full_present_tense, full_past_tense)
      @script             = script
    end

    # Invoke this command to call back upon +server.run_script+ 
    def perform(server)
      server.run_script(self, script)
    end

    # Provide a filename that represents this Command
    def to_filename
      @to_filename ||= "#{command} #{description}".gsub(/\W+/, '_')
    end

    # Stores the script on the local filesystem in a temporary directory
    # Returns path
    def as_file(&block)
      tmpdir = ENV['TMPDIR'] || "/tmp"
      script_path = File.join(tmpdir, to_filename)
      File.open(script_path, "w") do |f|
        f << @script
      end
      yield script_path
    end
  end
end
