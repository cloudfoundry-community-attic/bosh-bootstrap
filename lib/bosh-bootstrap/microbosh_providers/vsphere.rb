require "bosh-bootstrap/microbosh_providers/base"

module Bosh::Bootstrap::MicroboshProviders
  class VSphere < Base
    def stemcell
      unless settings.exists?("bosh.stemcell")
        download_stemcell
      end
    end

    def to_hash
      super.deep_merge({
        "network" => network_configuration,
        "resources" => resource_configuration,
        "cloud"=>
         {"plugin"=>"vsphere",
          "properties"=>{
            "vcenters"=>[vcenter_configuration]
          }}})
    end

    # network:
    #   ip: 172.23.194.100
    #   netmask: 255.255.254.0
    #   gateway: 172.23.194.1
    #   dns:
    #   - 172.22.22.153
    #   - 172.22.22.154
    #   cloud_properties:
    #     name: VLAN2194
    def network_configuration
      dns = settings.provider.network.dns
      dns = dns.split(",") if dns.is_a?(String)
      {
        "ip"=>public_ip,
        "netmask"=>settings.provider.network.netmask,
        "gateway"=>settings.provider.network.gateway,
        "dns"=>dns,
        "cloud_properties"=>{
          "name"=>settings.provider.network.name
        }
      }
    end

    # resources:
    #  persistent_disk: 32768
    #  cloud_properties:
    #    ram: 4096
    #    disk: 10240
    #    cpu: 2
    def resource_configuration
      {
        "persistent_disk"=>settings.provider.resources.persistent_disk,
        "cloud_properties"=>{
          "ram"=>settings.provider.resources.ram,
          "disk"=>settings.provider.resources.disk,
          "cpu"=>settings.provider.resources.cpu
        }
      }
    end

    # vcenters:
    # - host: HOST
    #   user: dev\cloudfoundry-auth
    #   password: TempP@ss
    #   datacenters:
    #     - name: LAS01
    #       vm_folder: BOSH_VMs
    #       template_folder: BOSH_Templates
    #       disk_path: BOSH_Deployer
    #       datastore_pattern: las01-.*
    #       persistent_datastore_pattern: las01-.*
    #       allow_mixed_datastores: true
    #       clusters:
    #       - CLUSTER01
    def vcenter_configuration
      clusters = settings.provider.datacenter.clusters
      clusters = clusters.split(",") if clusters.is_a?(String)
      {
        "host"=>settings.provider.credentials.vsphere_server,
        "user"=>settings.provider.credentials.vsphere_username,
        "password"=>settings.provider.credentials.vsphere_password,
        "datacenters"=>[{
          "name"=>settings.provider.datacenter.name,
          "vm_folder"=>settings.provider.datacenter.vm_folder,
          "template_folder"=>settings.provider.datacenter.template_folder,
          "disk_path"=>settings.provider.datacenter.disk_path,
          "datastore_pattern"=>settings.provider.datacenter.datastore_pattern,
          "persistent_datastore_pattern"=>settings.provider.datacenter.persistent_datastore_pattern,
          "allow_mixed_datastores"=>settings.provider.datacenter.allow_mixed_datastores,
          "clusters"=>clusters
        }]
      }
    end

    # @return Bosh::Cli::PublicStemcell latest stemcell for vsphere/trusty
    def latest_stemcell
      @latest_stemcell ||= begin
        trusty_stemcells = recent_stemcells.select do |s|
          s.name =~ /vsphere/ && s.name =~ /trusty/
        end
        trusty_stemcells.sort {|s1, s2| s2.version <=> s1.version}.first
      end
    end

  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("vsphere", Bosh::Bootstrap::MicroboshProviders::VSphere)
