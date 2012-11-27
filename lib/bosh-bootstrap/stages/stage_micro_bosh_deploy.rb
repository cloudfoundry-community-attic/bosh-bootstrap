module Bosh::Bootstrap::Stages
  class MicroBoshDeploy
    def commands
      @commands ||= Bosh::Bootstrap::Commander::Commands.new do |server|
        server.download "micro-bosh stemcell", script("download_micro_bosh_stemcell")
      end
    end

    private
    def stage_name
      "stage_micro_bosh_deploy"
    end

    def script(segment_name)
      path = File.expand_path("../#{stage_name}/#{segment_name}", __FILE__)
      if File.exist?(path)
        File.read(path)
      else
        Thor::Base.shell.new.say_status "error", "Missing script lib/bosh-bootstrap/stages/#{stage_name}/#{segment_name}", :red
        exit 1
      end
    end
  end
end
