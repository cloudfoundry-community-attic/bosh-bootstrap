# Copyright (c) 2012-2013 Stark & Wayne, LLC

module Bosh; module Providers; end; end

class Bosh::Providers::BaseProvider
  attr_reader :fog_compute

  def initialize(fog_compute)
    @fog_compute = fog_compute
  end

end
