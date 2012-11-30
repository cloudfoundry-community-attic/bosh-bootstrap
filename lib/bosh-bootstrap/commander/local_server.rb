require "popen4"

class Bosh::Bootstrap::Commander::LocalServer
  attr_reader :logfile

  def initialize(logfile=STDERR)
    @logfile = logfile
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
  def run_script(command, script, options={})
    command.as_file do |execution_command|
      `chmod +x #{execution_command}`
      status = POpen4::popen4(execution_command) do |stdout, stderr, stdin, pid|
        out = stdout.read
        logfile.puts out unless out.strip == ""
        err = stderr.read
        if err.strip != ""
          logfile.puts err
          STDERR.puts err if logfile != STDERR
        end
        logfile.flush
      end
      status.success?
    end
  rescue StandardError => e
    logfile.puts e.message
    false
  end

  # Upload a file (put a file into local filesystem)
  def upload_file(command, path, contents, upload_as_user=nil)
    basedir = File.dirname(path)
    unless File.directory?(basedir)
      logfile.puts "creating micro-bosh manifest folder: #{basedir}"
      FileUtils.mkdir_p(basedir)
    end
    logfile.puts "creating micro-bosh manifest: #{path}"
    File.open(path, "w") { |file| file << contents }
    true
  rescue StandardError => e
    logfile.puts e.message
    false
  end
end