require "highline"

module Bosh::Bootstrap::Cli::Helpers::Interactions
  def cyan; "\033[36m" end
  def clear; "\033[0m" end
  def bold; "\033[1m" end
  def red; "\033[31m" end
  def green; "\033[32m" end
  def yellow; "\033[33m" end

  # Helper to access HighLine for ask & menu prompts
  def hl
    @hl ||= HighLine.new(@stdin, @stdout)
  end
end