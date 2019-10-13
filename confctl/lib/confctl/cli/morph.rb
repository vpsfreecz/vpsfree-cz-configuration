module ConfCtl::Cli
  class Morph < Command
    MORPH_EXPR = File.realpath(File.join(Dir.pwd, 'morph.nix'))

    def list
      deps = ConfCtl::Deployments.new(show_trace: opts['show-trace'])

      puts sprintf(
        '%-30s %-12s %-12s %-12s %-15s %-10s %s',
        'HOST', 'TYPE', 'SPIN', 'ROLE', 'NAME', 'LOCATION', 'DOMAIN'
      )

      deps.each do |host, d|
        next if args[0] && !ConfCtl::Pattern.match?(args[0], host)

        puts sprintf(
          '%-30s %-12s %-12s %-12s %-15s %-10s %s',
          host, d.type, d.spin, d.role,
          rdomain(d.name), rdomain(d.location), rdomain(d.domain)
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
    def rdomain(domain)
      domain ? domain.split('.').reverse.join('.') : nil
    end
  end
end
