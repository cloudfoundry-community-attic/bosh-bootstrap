module Bosh::Bootstrap::Cli::Helpers
end

require "bosh-bootstrap/cli/helpers/interactions"
require "bosh-bootstrap/cli/helpers/settings"

module Bosh::Bootstrap::Cli::Helpers
  include Bosh::Bootstrap::Cli::Helpers::Interactions
  include Bosh::Bootstrap::Cli::Helpers::Settings
end
