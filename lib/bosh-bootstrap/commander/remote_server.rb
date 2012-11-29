class Bosh::Bootstrap::Commander::RemoteServer

  attr_reader :host
  attr_reader :username
  attr_reader :logfile

  def initialize(host, username, logfile=STDERR)
    @host, @username, @logfile = host, username, logfile
  end

  # Execute the +Command+ objects, in sequential order
  # upon the local server
  # +commands+ is a +Commands+ container
  #
  # Returns false once any subcommand fails to execute successfully
  def run(commands)
    commands.commands.each do |command|
      puts command.full_present_tense
      if command.perform(self)
        Thor::Base.shell.new.say "Successfully #{command.full_past_tense}", :green
      else
        Thor::Base.shell.new.say_status "error", "#{command.full_present_tense}", :red
        return false
      end
    end
  end

  #
  # Commands performed on local server
  # These map to Command subclasses, which then callback to these
  # local server specific implementations
  #

  # Run a script
  def run_script(command, script)
    true
  end

  # Upload a file (put a file into local filesystem)
  def upload_file(command, path, contents)
    true
  end
end