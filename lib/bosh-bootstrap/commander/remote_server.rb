require "net/scp"
require "tempfile"

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
  # Commands performed on remote server
  # These map to Command subclasses, which then callback to these
  # remote server specific implementations
  #

  # Run a script
  #
  # Uploads it to the remote server, makes it executable, then executes
  def run_script(command, script)
    logfile.puts "uploading #{command.to_filename} to Inception VM"
    remote_path = remote_tmp_script_path(command)
    upload_file(command, remote_path, script)
    run_remote_script(remote_path)
    true
  rescue StandardError => e
    logfile.puts e.message
    false
  end

  # Upload a file (put a file into the remote server's filesystem)
  def upload_file(command, remote_path, contents)
    Tempfile.open("remote_script") do |file|
      file << contents
      file.flush
      Net::SCP.upload!(host, username, file.path, remote_path)
    end
    true
  rescue StandardError => e
    logfile.puts e.message
    false
  end

  def remote_tmp_script_path(command)
    "/tmp/remote_script_#{command.to_filename}"
  end

  # Makes +remote_path+ executable, then runs it
  def run_remote_script(remote_path)
    Net::SSH.start(host, username) do |ssh|
      # make executable
      ssh.exec!("chmod +x #{remote_path}") do |channel, stream, data|
        logfile << data
      end
      # run script
      ssh.exec!("sudo #{remote_path}") do |channel, stream, data|
        logfile << data
      end
    end
  end
end