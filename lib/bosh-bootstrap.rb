# Requires Ruby language 1.9 and MRI or Rubinius
require "redcard"
RedCard.verify :mri, :ruby, :rubinius, "1.9"

module Bosh
  module Bootstrap
  end
end

require "bosh-bootstrap/version"
require "bosh-bootstrap/microbosh"
