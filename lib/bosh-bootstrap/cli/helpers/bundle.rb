# for the #sh helper
require "rake"
require "rake/file_utils"

require "bundler"

module Bosh::Bootstrap::Cli::Helpers::Bundle
  def bundle(*args)
    Bundler.with_clean_env {
      ENV.delete 'RUBYOPT'
      sh "bundle #{args.join(' ')}"
    }
  end

  def run(*args)
    Bundler.with_clean_env {
      ENV.delete 'RUBYOPT'
      sh *args
    }
  end
end
