require "net/scp"
require "tempfile"

class Bosh::Bootstrap::Commander::RemoteServer

  attr_reader :host
  attr_reader :private_key_path
  attr_reader :default_ssh_username
  attr_reader :logfile

  def initialize(host, private_key_path, logfile=STDERR)
    @host, @private_key_path, @logfile = host, private_key_path, logfile
    @default_ssh_username = "vcap" # unless overridden by a Command (before vcap exists)
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
  # Stores the last line of stripped STDOUT/STDERR into a settings field, 
  #   if :settings & :save_output_to_settings_key => "x.y.z" provided
  def run_script(command, script, options={})
    ssh_username = options[:ssh_username] || default_ssh_username
    run_as_root  = options[:run_as_root]
    settings     = options[:settings]
    settings_key = options[:save_output_to_settings_key]

    remote_path = remote_tmp_script_path(command)
    upload_file(command, remote_path, script, ssh_username)
    output, status = run_remote_script(remote_path, ssh_username, run_as_root)
    output =~ /^(.*)\Z/
    last_line = $1
    # store output into a settings field, if requested
    # TODO replace this with SettingsSetting#setting(settings_key, last_line.strip)
    if settings_key
      settings_key_portions = settings_key.split(".")
      parent_key_portions, final_key = settings_key_portions[0..-2], settings_key_portions[-1]
      target_settings_field = settings
      parent_key_portions.each do |key_portion|
        target_settings_field[key_portion] ||= {}
        target_settings_field = target_settings_field[key_portion]
      end
      target_settings_field[final_key] = last_line.strip
    end
    status
  rescue StandardError => e
    logfile.puts e.message
    false
  end

  # Upload a file (put a file into the remote server's filesystem)
  def upload_file(command, remote_path, contents, ssh_username=nil)
    upload_as_user = ssh_username || default_ssh_username
    run_remote_command("mkdir -p #{File.dirname(remote_path)}", upload_as_user)
    Tempfile.open("remote_script") do |file|
      file << contents
      file.flush
      logfile.puts "uploading #{remote_path} to Inception VM"
      Net::SCP.upload!(host, upload_as_user, file.path, remote_path, ssh: { keys: private_keys })
    end
    true
  rescue StandardError => e
    logfile.puts "ERROR running upload_file(#{command.class}, '#{remote_path}', ...)"
    logfile.puts e.message
    logfile.puts e.backtrace
    false
  end

  private
  def remote_tmp_script_path(command)
    "/tmp/remote_script_#{command.to_filename}"
  end

  # Makes +remote_path+ executable, then runs it
  # Returns:
  # * a String of all STDOUT/STDERR; which is also appended to +logfile+
  # * status (true = success)
  #
  # TODO catch exceptions http://learnonthejob.blogspot.com/2010/08/exception-handling-for-netssh.html
  def run_remote_script(remote_path, ssh_username, run_as_root)
    sudo = run_as_root ? "sudo " : ""
    commands = [
      "chmod +x #{remote_path}",
      "bash -lc '#{sudo}/usr/bin/env PATH=$PATH #{remote_path}'"
    ]
    script_output = ""
    results = Fog::SSH.new(host, ssh_username, keys: private_keys).run(commands) do |stdout, stderr|
      [stdout, stderr].flatten.each do |data|
        logfile << data
        script_output << data
      end
    end
    result = results.last
    result_success = result.status == 0
    [script_output, result_success]
  end

  def run_remote_command(command, username)
    Net::SSH.start(host, username, keys: private_keys) do |ssh|
      ssh.exec!("bash -lc '#{command}'") do |channel, stream, data|
        logfile << data
      end
    end
  end

  # path to local private key being used
  def private_keys
    [private_key_path]
  end

end