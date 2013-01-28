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

  # Creates or reuses an AWS security group and opens ports.
  # 
  # +security_group_name+ is the name to be created or reused
  # +ports+ is a hash of name/port for ports to open, for example:
  # {
  #   ssh: 22,
  #   http: 80,
  #   https: 443
  # }
  def create_security_group(security_group_name, description, ports)
    unless sg = fog_compute.security_groups.get(security_group_name)
      sg = fog_compute.security_groups.create(name: security_group_name, description: description)
      puts "Created security group #{security_group_name}"
    else
      puts "Reusing security group #{security_group_name}"
    end
    ip_permissions = sg.ip_permissions
    ports_opened = 0
    ports.each do |name, port|
      unless port_open?(ip_permissions, port)
        sg.authorize_port_range(port..port)
        puts " -> opened #{name} port #{port}"
        ports_opened += 1
      end
    end
    puts " -> no additional ports opened" if ports_opened == 0
    true
  end

  def port_open?(ip_permissions, port)
    ip_permissions && ip_permissions.find {|ip| ip["fromPort"] <= port && ip["toPort"] >= port }
  end
end
