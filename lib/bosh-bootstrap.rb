# Requires Ruby language 1.9 and MRI or Rubinius
require "redcard"
RedCard.verify :mri, :ruby, :rubinius, "1.9"

class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

module Bosh
  module Bootstrap
  end
end

require "bosh-bootstrap/version"
require "bosh-bootstrap/network"
require "bosh-bootstrap/key_pair"
require "bosh-bootstrap/microbosh"
