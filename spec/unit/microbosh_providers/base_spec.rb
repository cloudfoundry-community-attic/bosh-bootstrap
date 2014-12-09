
require "readwritesettings"
require "bosh-bootstrap/microbosh_providers/base"

describe Bosh::Bootstrap::MicroboshProviders::Base do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}
  let(:fog_compute) { instance_double("Fog::Compute::Base") }
  subject{ Bosh::Bootstrap::MicroboshProviders::Base.new(microbosh_yml, settings, fog_compute ) }


  context "creates micro_bosh.yml manifest" do
    before { setting "bosh.name", "test-bosh" }

    context "when recursor is provided" do
      it "adds the recursor to the yml" do
        setting "recursor", "4.5.6.7"

        subject.create_microbosh_yml(settings)
        File.should be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.base.with_recursor.yml"))
      end
    end

    context "when recursor is not provided" do
      it "does not adds the recursor to the yml" do
        subject.create_microbosh_yml(settings)
        File.should be_exists(microbosh_yml)
        yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/micro_bosh.base.without_recursor.yml"))
      end
    end
  end
end
