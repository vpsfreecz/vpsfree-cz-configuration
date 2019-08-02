require 'json'

module ConfCtl::Cli
  class Morph < Command
    DEPLOYMENTS_EXPR = File.realpath(File.join(Dir.pwd, 'deployments.nix'))
    MORPH_EXPR = File.realpath(File.join(Dir.pwd, 'morph.nix'))

    def list
      cmd = [
        'nix-instantiate',
        '--eval',
        '--json',
        '--strict',
        '--arg', 'deploymentsExpr', DEPLOYMENTS_EXPR,
        '--attr', 'deploymentsInfo',
        (opts['show-trace'] ? '--show-trace' : ''),
        asset('eval-machines.nix'),
      ]

      json = `#{cmd.join(' ')}`

      if $?.exitstatus != 0
        fail "nix-instantiate failed with exit status #{$?.exitstatus}"
      end

      hosts = JSON.parse(json)

      puts sprintf(
        '%-30s %-12s %-12s %-15s %-10s %s',
        'HOST', 'TYPE', 'SPIN', 'NAME', 'LOCATION', 'DOMAIN'
      )

      hosts.each do |host, info|
        next if args[0] && !ConfCtl::Pattern.match?(args[0], host)

        puts sprintf(
          '%-30s %-12s %-12s %-15s %-10s %s',
          host, info['type'], info['spin'], info['name'], info['location'], info['domain']
        )
      end
    end

    def build
      cmd = [
        'morph',
        'build',
      ]

      cmd << "--on=#{args[0]}" if args[0]
      cmd << '--show-trace' if opts['show-trace']
      cmd << MORPH_EXPR

      Process.exec(*cmd)
    end

    def deploy
      cmd = [
        'morph',
        'deploy',
      ]

      cmd << "--on=#{args[0]}" if args[0]
      cmd << '--show-trace' if opts['show-trace']
      cmd << MORPH_EXPR
      cmd << (args[1] || 'switch')

      Process.exec(*cmd)
    end

    def check_health
      cmd = [
        'morph',
        'check-health',
      ]

      cmd << "--on=#{args[0]}" if args[0]
      cmd << '--show-trace' if opts['show-trace']
      cmd << MORPH_EXPR

      Process.exec(*cmd)
    end

    protected
    def asset(name)
      File.join(File.dirname(__FILE__), '../../..', 'assets', name)
    end
  end
end
