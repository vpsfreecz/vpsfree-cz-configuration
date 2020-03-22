require 'json'

module ConfCtl
  class Deployments
    DEPLOYMENTS_EXPR = File.join(ConfCtl.root, 'deployments.nix')

    Deployment = Struct.new(
      :managed, :type, :spin, :role, :name, :location, :domain, :fqdn, :config
    )

    # @param opts [Hash]
    # @option opts [Boolean] :show_trace
    # @option opts [Boolean] :deployments
    def initialize(opts = {})
      @opts = opts
      @deployments = opts[:deployments] || parse(extract)
    end

    # @yieldparam [String] host
    # @yieldparam [Deployment] deployment
    def each(&block)
      deployments.each(&block)
    end

    # @yieldparam [String] host
    # @yieldparam [Deployment] deployment
    # @return [Deployments]
    def select(&block)
      self.class.new(deployments: deployments.select(&block))
    end

    # @yieldparam [String] host
    # @yieldparam [Deployment] deployment
    # @return [Array]
    def map(&block)
      deployments.map(&block)
    end

    # @return [Deployments]
    def managed
      select { |host, dep| dep.managed }
    end

    # @return [Deployments]
    def unmanaged
      select { |host, dep| !dep.managed }
    end

    protected
    attr_reader :opts, :deployments

    def extract
      cmd = [
        'nix-instantiate',
        '--eval',
        '--json',
        '--strict',
        '--read-write-mode',
        '--arg', 'deploymentsExpr', DEPLOYMENTS_EXPR,
        '--attr', 'deploymentsInfo',
        (opts[:show_trace] ? '--show-trace' : ''),
        ConfCtl.asset('eval-machines.nix'),
      ]

      json = `#{cmd.join(' ')}`

      if $?.exitstatus != 0
        fail "nix-instantiate failed with exit status #{$?.exitstatus}"
      end

      json
    end

    def parse(data)
      Hash[JSON.parse(data).map do |host, info|
        [host, Deployment.new(
          info['managed'],
          info['type'],
          info['spin'],
          info['role'],
          info['name'],
          info['location'],
          info['domain'],
          info['fqdn'],
          info['config'],
        )]
      end]
    end
  end
end
