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

  # Provision an EC2 or VPC elastic IP addess.
  # * VPC - provision_public_ip_address(vpc: true)
  # * EC2 - provision_public_ip_address
  # @return [String] provisions a new public IP address in target region
  # TODO nil if none available
  def provision_public_ip_address(options={})
    if options.delete(:vpc)
      options[:domain] = "vpc"
    else
      options[:domain] = options.delete(:domain) || "standard"
    end
    address = fog_compute.addresses.create(options)
    address.public_ip
    # TODO catch error and return nil
  end

  def associate_ip_address_with_server(ip_address, server)
    address = fog_compute.addresses.get(ip_address)
    address.server = server
  end

  def create_vpc(name, cidr_block)
    vpc = fog_compute.vpcs.create(name: name, cidr_block: cidr_block)
    vpc.id
  end

  # Creates a VPC subnet
  # @return [String] the subnet_id
  def create_subnet(vpc_id, cidr_block)
    subnet = fog_compute.subnets.create(vpc_id: vpc_id, cidr_block: cidr_block)
    subnet.subnet_id
  end

  def create_internet_gateway(vpc_id)
    gateway = fog_compute.internet_gateways.create(vpc_id: vpc_id)
    gateway.id
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
  #   mosh: { protocol: "rdp", ports: (3398..3398), ip_ranges: [ { cidrIp: "196.212.12.34/32" } ] }
  # }
  # In this example, 
  #  * TCP 22 will be opened for ssh from any ip_range,
  #  * TCP ports 80, 81, 82 for http from any ip_range,
  #  * UDP 60000 -> 60050 for mosh from any ip_range and
  #  * TCP 3398 for RDP from ip range: 96.212.12.34/32
  def create_security_group(security_group_name, description, ports)
    unless sg = fog_compute.security_groups.get(security_group_name)
      sg = fog_compute.security_groups.create(name: security_group_name, description: description)
      puts "Created security group #{security_group_name}"
    else
      puts "Reusing security group #{security_group_name}"
    end
    ip_permissions = sg.ip_permissions
    ports_opened = 0
    ports.each do |name, port_defn|
      (protocol, port_range, ip_range) = extract_port_definition(port_defn)
      unless port_open?(ip_permissions, port_range, protocol, ip_range)
        sg.authorize_port_range(port_range, {:ip_protocol => protocol, :cidr_ip => ip_range})
        puts " -> opened #{name} ports #{protocol.upcase} #{port_range.min}..#{port_range.max} from IP range #{ip_range}"
        ports_opened += 1
      end
    end
    puts " -> no additional ports opened" if ports_opened == 0
    true
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

  def port_open?(ip_permissions, port_range, protocol, ip_range)
    ip_permissions && ip_permissions.find do |ip| 
      ip["ipProtocol"] == protocol \
      && ip["ipRanges"].detect { |range| range["cidrIp"] == ip_range } \
      && ip["fromPort"] <= port_range.min \
      && ip["toPort"] >= port_range.max
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

  def bootstrap(new_attributes = {})
    vpc = new_attributes[:subnet_id]

    server = fog_compute.servers.new(new_attributes)

    unless new_attributes[:key_name]
      # first or create fog_#{credential} keypair
      name = Fog.respond_to?(:credential) && Fog.credential || :default
      unless server.key_pair = fog_compute.key_pairs.get("fog_#{name}")
        server.key_pair = fog_compute.key_pairs.create(
          :name => "fog_#{name}",
          :public_key => server.public_key
        )
      end
    end

    if vpc
      # TODO setup security group on new server
    else
      # make sure port 22 is open in the first security group
      security_group = fog_compute.security_groups.get(server.groups.first)
      authorized = security_group.ip_permissions.detect do |ip_permission|
        ip_permission['ipRanges'].first && ip_permission['ipRanges'].first['cidrIp'] == '0.0.0.0/0' &&
        ip_permission['fromPort'] == 22 &&
        ip_permission['ipProtocol'] == 'tcp' &&
        ip_permission['toPort'] == 22
      end
      unless authorized
        security_group.authorize_port_range(22..22)
      end
    end

    server.save
    server.wait_for { ready? }
    server.setup(:key_data => [server.private_key])
    server
  end

end
