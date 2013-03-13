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

  # Any of the following +port_defn+ can be used:
  # {
  #   ssh: 22,
  #   http: { ports: (80..82) },
  #   mosh: { protocol: "udp", ports: (60000..60050) }
  #   mosh: { protocol: "rdp", ports: (3398..3398), ip_range: "196.212.12.34/32" }
  # }
  # In this example,
  #  * TCP 22 will be opened for ssh from any ip_range,
  #  * TCP ports 80, 81, 82 for http from any ip_range,
  #  * UDP 60000 -> 60050 for mosh from any ip_range and
  #  * TCP 3398 for RDP from ip range: 96.212.12.34/32
  def extract_port_definition(port_defn)
    protocol = "tcp"
    ip_range = "0.0.0.0/0"
    if port_defn.is_a? Integer
      port_range = (port_defn..port_defn)
    elsif port_defn.is_a? Range
      port_range = port_defn
    elsif port_defn.is_a? Hash
      protocol = port_defn[:protocol] if port_defn[:protocol]
      port_range = port_defn[:ports]  if port_defn[:ports]
      ip_range = port_defn[:ip_range] if port_defn[:ip_range]
    end
    [protocol, port_range, ip_range]
  end
end
