# Copyright (c) 2012-2013 Stark & Wayne, LLC

module Bosh; module Providers; end; end

class Bosh::Providers::BaseProvider
  attr_reader :fog_compute

  def initialize(fog_compute)
    @fog_compute = fog_compute
  end

  def create_key_pair(key_pair_name)
    fog_compute.key_pairs.create(:name => key_pair_name)
  end

  def delete_key_pair_if_exists(key_pair_name)
    if fog_key_pair = fog_compute.key_pairs.get(key_pair_name)
      fog_key_pair.destroy
    end
  end
end
