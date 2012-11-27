# A single command/script to be run on a local/remote server
# For the display, it has an active ("installing") and 
# past tense ("installed") verb and a noub/description ("packages")
class Bosh::Bootstrap::Commander::Command
  attr_reader :command       # verb e.g. "install"
  attr_reader :description   # noun phrase, e.g. "packages"
  attr_reader :script

  attr_reader :full_present_tense  # e.g. "installing packages"
  attr_reader :full_past_tense    # e.g. "installed packages"
  
  def initialize(command, description, script, full_present_tense=nil, full_past_tense=nil)
    @command            = command
    @description        = description
    @script             = script
    @full_present_tense = full_present_tense || "#{command} #{description}"
    @full_past_tense    = full_past_tense || "#{command} #{description}"
  end

  # Provide a filename that represents this Command
  def to_filename
    @to_filename ||= "#{command} #{description}".gsub(/\W+/, '_')
  end

  # Stores the script on the local filesystem in a temporary directory
  # Returns path
  def as_file(&block)
    script_path = File.join(ENV['TMPDIR'], to_filename)
    File.open(script_path, "w") do |f|
      f << @script
    end
    yield script_path
  end
end
