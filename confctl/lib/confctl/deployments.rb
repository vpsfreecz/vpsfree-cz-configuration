require 'json'

module ConfCtl
  class Deployments
    DEPLOYMENTS_EXPR = File.join(ConfCtl.root, 'deployments.nix')

    Deployment = Struct.new(:type, :spin, :role, :name, :location, :domain, :fqdn)

    # @param opts [Hash]
    # @option opts [Boolean] :show_trace
    def initialize(opts = {})
      @opts = opts
      @deployments = parse(extract)
    end

    # @yieldparam [String] host
    # @yieldparam [Deployment] deployment
    def each(&block)
      deployments.each(&block)
    end

    protected
    attr_reader :opts, :deployments

    def extract
      cmd = [
        'nix-instantiate',
        '--eval',
        '--json',
        '--strict',
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
          info['type'],
          info['spin'],
          info['role'],
          info['name'],
          info['location'],
          info['domain'],
          info['fqdn'],
        )]
      end]
    end
  end
end
