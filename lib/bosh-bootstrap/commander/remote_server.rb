require "net/scp"
require "tempfile"

class Bosh::Bootstrap::Commander::RemoteServer

  attr_reader :host
  attr_reader :default_username
  attr_reader :logfile

  def initialize(host, logfile=STDERR)
    @host, @logfile = host, logfile
    @default_username = "vcap" # unless overridden by a Command (before vcap exists)
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
  def run_script(command, script, options={})
    run_as_user = options[:user] || default_username
    remote_path = remote_tmp_script_path(command)
    upload_file(command, remote_path, script, run_as_user)
    run_remote_script(remote_path, run_as_user)
    true
  rescue StandardError => e
    logfile.puts e.message
    false
  end

  # Upload a file (put a file into the remote server's filesystem)
  def upload_file(command, remote_path, contents, upload_as_user=nil)
    upload_as_user ||= default_username
    run_remote_command("mkdir -p #{File.dirname(remote_path)}", upload_as_user)
    Tempfile.open("remote_script") do |file|
      file << contents
      file.flush
      logfile.puts "uploading #{remote_path} to Inception VM"
      Net::SCP.upload!(host, upload_as_user, file.path, remote_path)
    end
    true
  rescue StandardError => e
    logfile.puts e.message
    false
  end

  private
  def remote_tmp_script_path(command)
    "/tmp/remote_script_#{command.to_filename}"
  end

  # Makes +remote_path+ executable, then runs it
  def run_remote_script(remote_path, username)
    Net::SSH.start(host, username) do |ssh|
      # make executable
      ssh.exec!("chmod +x #{remote_path}") do |channel, stream, data|
        logfile << data
      end
      # run script
      logfile.puts %Q{running on remote server: "bash -lc 'sudo /usr/bin/env PATH=$PATH GEM_PATH=$GEM_PATH GEM_HOME=$GEM_HOME #{remote_path}'"}
      ssh.exec!("bash -lc 'sudo /usr/bin/env PATH=$PATH GEM_PATH=$GEM_PATH GEM_HOME=$GEM_HOME #{remote_path}'") do |channel, stream, data|
        logfile << data
      end
    end
  end

  def run_remote_command(command, username)
    Net::SSH.start(host, username) do |ssh|
      ssh.exec!("bash -lc '#{command}'") do |channel, stream, data|
        logfile << data
      end
    end
  end
end