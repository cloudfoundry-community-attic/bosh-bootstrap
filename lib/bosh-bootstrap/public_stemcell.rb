module Bosh::Bootstrap
  class PublicStemcell
    attr_reader :size

    def initialize(key, size)
      @key = key
      @size = size

      @parsed_version = key.scan(/[\d]*_?[\d]+/).first
    end

    def name
      File.basename(@key)
    end

    def version
      @parsed_version.gsub('_', '.')
    end

    def variety
      name.gsub(/(.tgz)|(bosh-stemcell-)|(#{@parsed_version})/, '').split('-').reject { |c| c.empty? }.join('-')
    end

    # @return [String] guesses ultimate stemcell name from file name
    # light-bosh-stemcell-2719-aws-xen-ubuntu-trusty-go_agent.tgz into bosh-aws-xen-ubuntu-trusty-go_agent
    def stemcell_name
      name.
        gsub(/(.tgz)|(#{@parsed_version})/, '').
        gsub(/^.*bosh-stemcell-/, 'bosh-').
        split('-').reject { |c| c.empty? }.join('-')
    end

    def url
      "#{PublicStemcells::PUBLIC_STEMCELLS_BASE_URL}/#{@key}"
    end

    def legacy?
      @key.include?('legacy')
    end

  end
end
