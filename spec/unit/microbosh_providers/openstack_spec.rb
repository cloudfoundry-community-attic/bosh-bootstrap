require "readwritesettings"
require "bosh-bootstrap/microbosh_providers/openstack"

describe Bosh::Bootstrap::MicroboshProviders::OpenStack do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:fog_compute) { instance_double("Fog::Compute::OpenStack") }
  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}

  describe "microbosh yml" do
    subject do
      Bosh::Bootstrap::MicroboshProviders::OpenStack
        .new(microbosh_yml, settings, fog_compute)
    end

    before do
      setting "provider.name", "openstack"
      setting "provider.credentials.openstack_auth_url", "http://10.0.0.2:5000/v2.0/tokens"
      setting "provider.credentials.openstack_username", "USER"
      setting "provider.credentials.openstack_api_key", "PASSWORD"
      setting "provider.credentials.openstack_tenant", "TENANT"
      setting "provider.credentials.openstack_region", "REGION"
      setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
      setting "bosh.name", "test-bosh"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.persistent_disk", 32768
    end

    context "on nova with floating IP" do
      before do
        setting "address.ip", "1.2.3.4"
      end

      it "creates micro_bosh.yml manifest" do
        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.nova_vip.yml"))
      end

    end

    context "on neutron with public gateway & floating IP" do
      before do
        setting "address.subnet_id", "7b8788eb-b49e-4424-9065-75a6b07094ea"
        setting "address.pool_name", "INTERNET"
        setting "address.ip", "1.2.3.4" # network.vip
      end

      it "creates micro_bosh.yml manifest" do
        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.neutron_vip.yml"))
      end

    end
    context "on neutron with internal static IP only" do
      before do
        setting "address.subnet_id", "7b8788eb-b49e-4424-9065-75a6b07094ea"
        setting "address.ip", "10.10.10.3" # network.ip
      end

      it "creates micro_bosh.yml manifest" do
        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.neutron_manual.yml"))
      end

    end
    context "settings" do
      before do
        setting "address.ip", "10.10.10.3" # network.ip
        setting "address.subnet_id", "7b8788eb-b49e-4424-9065-75a6b07094ea"
      end

      it "boot from volume" do
        setting "provider.options.boot_from_volume", true

        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.boot_from_volume.yml"))
      end

      it "adds recursor if present" do
        setting "recursor", "4.5.6.7"

        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.with_recursor.yml"))
      end

      it "adds proxy if present" do
        setting "proxy.http_proxy", "http://192.168.1.100:8080"
        setting "proxy.https_proxy", "https://192.168.1.100:8080"

        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.with_proxy.yml"))
      end

      it "adds state_timeout if provided" do
        setting "provider.state_timeout", 600

        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.with_state_timeout.yml"))
      end

      it "uses custom ntp if provided" do
        setting "ntp", %w[1.1.2.2 1.1.2.3]


        subject.create_microbosh_yml(settings)
        expect(File).to be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.openstack.with_ntp.yml"))
      end
    end
  end

  describe "existing stemcells as openstack images" do
    it "finds match" do
      subject = Bosh::Bootstrap::MicroboshProviders::OpenStack
                .new(microbosh_yml, settings, fog_compute)
      expect(subject).to receive(:owned_images).and_return([
        instance_double("Fog::Compute::OpenStack::Image",
          name: "BOSH-14c85f35-3dd3-4200-af85-ada65216b2de",
          metadata: [
            instance_double("Fog::Compute::OpenStack::Metadata",
              key: "name", value: "bosh-openstack-kvm-ubuntu-trusty-go_agent"),
            instance_double("Fog::Compute::OpenStack::Metadata",
              key: "version", value: "2732"),
          ]
        )
      ])
      expect(subject.find_image_for_stemcell("bosh-openstack-kvm-ubuntu-trusty-go_agent", "2732")).to eq("BOSH-14c85f35-3dd3-4200-af85-ada65216b2de")
    end

    it "doesn't find match" do
      subject = Bosh::Bootstrap::MicroboshProviders::OpenStack.new(microbosh_yml, settings, fog_compute)
      expect(subject).to receive(:owned_images).and_return([])
      expect(subject.find_image_for_stemcell("xxxx", "12345")).to be_nil
    end
  end
end
