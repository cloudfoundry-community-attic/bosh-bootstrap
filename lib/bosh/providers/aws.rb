# Copyright (c) 2012-2013 Stark & Wayne, LLC

module Bosh; module Providers; end; end

require "bosh/providers/base_provider"

class Bosh::Providers::AWS < Bosh::Providers::BaseProvider
  # supported by fog 1.6.0
  # FIXME weird that fog has no method to return this list
  def region_labels
    ['ap-northeast-1', 'ap-southeast-1', 'eu-west-1', 'sa-east-1', 'us-east-1', 'us-west-1', 'us-west-2']
  end

  def default_region_label
    'us-east-1'
  end

  # @return [Integer] megabytes of RAM for requested flavor of server
  def ram_for_server_flavor(server_flavor_id)
    if flavor = fog_compute_flavor(server_flavor_id)
      flavor[:ram]
    else
      raise "Unknown AWS flavor '#{server_flavor_id}'"
    end
  end

  # @return [Hash] e.g. { :bits => 0, :cores => 2, :disk => 0, 
  #   :id => 't1.micro', :name => 'Micro Instance', :ram => 613}
  # or nil if +server_flavor_id+ is not a supported flavor ID
  def fog_compute_flavor(server_flavor_id)
    aws_compute_flavors.find { |fl| fl[:id] == server_flavor_id }
  end

  # @return [Array] of [Hash] for each supported compute flavor
  # Example [Hash] { :bits => 0, :cores => 2, :disk => 0, 
  #   :id => 't1.micro', :name => 'Micro Instance', :ram => 613}
  def aws_compute_flavors
    Fog::Compute::AWS::FLAVORS
  end

  def aws_compute_flavor_ids
    aws_compute_flavors.map { |fl| fl[:id] }
  end

  # @return [String] provisions a new public IP address in target region
  # TODO nil if none available
  def provision_public_ip_address
    address = fog_compute.addresses.create
    address.public_ip
    # TODO catch error and return nil
  end

  def associate_ip_address_with_server(ip_address, server)
    address = fog_compute.addresses.get(ip_address)
    address.server = server
  end

  # Creates or reuses an AWS security group and opens ports.
  # 
  # +security_group_name+ is the name to be created or reused
  # +ports+ is a hash of name/port for ports to open, for example:
  # {
  #   ssh: 22,
  #   http: 80,
  #   https: 443
  # }
  # protocol defaults to TCP
  # You can also use a more verbose +ports+ using the format:
  # {
  #   ssh: 22,
  #   http: { ports: (80..82) },
  #   mosh: { protocol: "udp", ports: (60000..60050) }
  # }
  # In this example, 
  #  * TCP 22 will be opened for ssh, 
  #  * TCP ports 80, 81, 82 for http and
  #  * UDP 60000 -> 60050 for mosh
  def create_security_group(security_group_name, description, ports)
    unless sg = fog_compute.security_groups.get(security_group_name)
      sg = fog_compute.security_groups.create(name: security_group_name, description: description)
      puts "Created security group #{security_group_name}"
    else
      puts "Reusing security group #{security_group_name}"
    end

    ip_permissions = sg.ip_permissions || []
    ports.each do |name, port_defn|
      (protocol, port_range) = extract_port_definition(port_defn)
      puts " -> #{name}:" 
      if closest_rule = find_closest_rule(ip_permissions, port_range, protocol)
        current_ports   = (closest_rule["fromPort"]..closest_rule["toPort"]) 
        puts "    - requested rule #{protocol.upcase} #{port_range.inspect} overlaps with existing rule: #{protocol.upcase} #{current_ports.inspect}"
        puts "    - removing existing overlapping rule: #{protocol.upcase} #{current_ports.inspect}"
        sg.revoke_port_range( current_ports, { :ip_protocol => closest_rule['ipProtocol'] } )
 
        if closest_rule["fromPort"] < port_range.min
          puts "    - decreasing port_range.min from #{port_range.min} to #{closest_rule["fromPort"]}"
          port_range = (closest_rule["fromPort"]..port_range.max)
        end
        if closest_rule["toPort"] > port_range.max 
          puts "    - increasing port_range.max from #{port_range.max} to #{closest_rule["toPort"]}"
          port_range = ( port_range.min..closest_rule["toPort"] )
        end
      end
      puts "    => creating rule #{protocol.upcase} #{port_range.inspect}" 
      sg.authorize_port_range(port_range, {:ip_protocol => protocol})
    end

    true
  end

  # Any of the following +port_defn+ can be used:
  # {
  #   ssh: 22,
  #   http: { ports: (80..82) },
  #   mosh: { protocol: "udp", ports: (60000..60050) }
  # }
  # In this example, 
  #  * TCP 22 will be opened for ssh, 
  #  * TCP ports 80, 81, 82 for http and
  #  * UDP 60000 -> 60050 for mosh
  def extract_port_definition(port_defn)
    if port_defn.is_a? Integer
      protocol = "tcp"
      port_range = (port_defn..port_defn)
    elsif port_defn.is_a? Range
      protocol = "tcp"
      port_range = port_defn
    elsif port_defn.is_a? Hash
      protocol = port_defn[:protocol]
      port_range = port_defn[:ports]
    end
    [protocol, port_range]
  end

  def find_closest_rule(ip_permissions, port_range, protocol)
    ip_permissions.find do |rule| 
      rule["ipProtocol"] == protocol && \
      #     given     |--------|         is the requested port_range
      # (a) match     |--------|         rule with same range
      # (b) match    |-----------|       rule with larger range
      # (c) match    |----|              rule with left-lapping range
      # (d) match             |----|     rule with right-lapping range
      # (e) match         |--|           rule inside range
      #     not                     |-|  rule outside range
      #     not   |-|                    rule outside range
      (   ( rule["fromPort"] >= port_range.min && rule["fromPort"] <= port_range.max ) \
       || ( rule["toPort"]   >= port_range.min && rule["toPort"]   <= port_range.max ) \
       || ( rule["fromPort"] <= port_range.min && rule["toPort"] >= port_range.max ) \
      )
    end
  end

  def find_server_device(server, device)
    server.volumes.all.find {|v| v.device == device}
  end

  def create_and_attach_volume(name, disk_size, server, device)
    volume = fog_compute.volumes.create(
        size: disk_size,
        name: name,
        description: '',
        device: device,
        availability_zone: server.availability_zone)
    # TODO: the following works in fog 1.9.0+ (but which has a bug in bootstrap)
    # https://github.com/fog/fog/issues/1516
    #
    # volume.wait_for { volume.status == 'available' }
    # volume.attach(server.id, "/dev/vdc")
    # volume.wait_for { volume.status == 'in-use' }
    #
    # Instead, using:
    volume.server = server
  end
end
