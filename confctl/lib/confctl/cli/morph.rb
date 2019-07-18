require 'json'

module ConfCtl::Cli
  class Morph < Command
    EXPR = File.realpath(File.join(Dir.pwd, 'morph.nix'))

    def list
      ENV['IN_CONFCTL'] = 'true'

      cmd = [
        'nix-instantiate',
        '--eval',
        '--json',
        '--strict',
        '--arg', 'networkExpr', EXPR,
        '--attr', 'machineInfo',
        (opts['show-trace'] ? '--show-trace' : ''),
        asset('eval-machines.nix'),
      ]

      json = `#{cmd.join(' ')}`

      if $?.exitstatus != 0
        fail "nix-instantiate failed with exit status #{$?.exitstatus}"
      end

      hosts = JSON.parse(json)

      puts sprintf(
        '%-30s %-12s %-15s %-10s %s',
        'HOST', 'TYPE', 'NAME', 'LOCATION', 'DOMAIN'
      )

      hosts.each do |host, info|
        next if args[0] && !ConfCtl::Pattern.match?(args[0], host)

        puts sprintf(
          '%-30s %-12s %-15s %-10s %s',
          host, info['type'], info['name'], info['location'], info['domain']
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
      cmd << EXPR

      Process.exec(*cmd)
    end

    protected
    def asset(name)
      File.join(File.dirname(__FILE__), '../../..', 'assets', name)
    end
  end
end
