# Requires Ruby language 1.9 and MRI or Rubinius
require "redcard"
RedCard.check :mri, :rubinius, "1.9"

module Bosh
  module Bootstrap
  end
end

require "bosh-bootstrap/version"
require "bosh-bootstrap/commander"
require "bosh-bootstrap/stages"

require "bosh/providers"
