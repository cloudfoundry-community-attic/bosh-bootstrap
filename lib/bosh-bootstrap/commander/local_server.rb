require "popen4"

class Bosh::Bootstrap::Commander::LocalServer
  # Execute the +Command+ objects, in sequential order
  # upon the local server
  # +commands+ is a +Commands+ container
  #
  # Returns false once any subcommand fails to execute successfully
  def run(commands, logfile=STDERR)
    commands.commands.each do |command|
      puts command.full_present_tense

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
        end
        unless status.success?
          Thor::Base.shell.new.say_status "error", "#{command.full_present_tense}", :red
          return false
        end
      end
      Thor::Base.shell.new.say "Successfully #{command.full_past_tense}", :green
    end
  end
end