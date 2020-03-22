module ConfCtl::Cli
  class Morph < Command
    MORPH_EXPR = File.realpath(File.join(Dir.pwd, 'morph.nix'))

    def list
      deps = ConfCtl::Deployments.new(show_trace: opts['show-trace'])
      selected = select_deployments(args[0])

      managed =
        case opts[:managed]
        when 'y', 'yes'
          selected.managed
        when 'n', 'no'
          selected.unmanaged
        when 'a', 'all'
          selected
        else
          selected.managed
        end

      list_deployments(managed)
    end

    def build
      cmd = [
        'morph',
        'build',
      ]

      deps = select_deployments(args[0]).managed

      ask_confirmation! do
        puts "The following deployments will be built:"
        list_deployments(deps)
      end

      cmd << "--on={#{deps.map { |host, d| host }.join(',')}}"
      cmd << '--show-trace' if opts['show-trace']
      cmd << MORPH_EXPR

      puts "Executing #{cmd.map { |v| "\"#{v}\"" }.join(' ')}"
      puts
      Process.exec(*cmd)
    end

    def deploy
      cmd = [
        'morph',
        'deploy',
      ]

      deps = select_deployments(args[0]).managed
      action = args[1] || 'switch'

      unless %w(boot switch test dry-activate).include?(action)
        raise GLI::BadCommandLine, "invalid action '#{action}'"
      end

      ask_confirmation! do
        puts "The following deployments will be built and deployed:"
        list_deployments(deps)
        puts
        puts "Target action: #{action}"
      end

      cmd << "--on={#{deps.map { |host, d| host }.join(',')}}"
      cmd << '--show-trace' if opts['show-trace']
      cmd << '--skip-health-checks' unless opts['health-checks']
      cmd << MORPH_EXPR
      cmd << action

      puts "Executing #{cmd.map { |v| "\"#{v}\"" }.join(' ')}"
      puts
      Process.exec(*cmd)
    end

    def check_health
      cmd = [
        'morph',
        'check-health',
      ]

      deps = select_deployments(args[0]).managed

      cmd << "--on={#{deps.map { |host, d| host }.join(',')}}"
      cmd << '--show-trace' if opts['show-trace']
      cmd << MORPH_EXPR

      puts "Executing #{cmd.map { |v| "\"#{v}\"" }.join(' ')}"
      puts
      Process.exec(*cmd)
    end

    protected
    def select_deployments(pattern)
      deps = ConfCtl::Deployments.new(show_trace: opts['show-trace'])

      deps.select do |host, d|
        (pattern.nil? || ConfCtl::Pattern.match?(pattern, host)) \
          && (opts[:type].nil? || opts[:type] == d.type) \
          && (opts[:spin].nil? || opts[:spin] == d.spin) \
          && (opts[:role].nil? || opts[:role] == d.role)
      end
    end

    def ask_confirmation
      return true if opts[:yes]

      yield
      STDOUT.write("\nContinue? [y/N]: ")
      STDOUT.flush
      STDIN.readline.strip.downcase == 'y'
    end

    def ask_confirmation!(&block)
      fail 'Aborted' unless ask_confirmation(&block)
    end

    def list_deployments(deps)
      fmt, cols, fmtopts = printf_fmt_cols
      puts sprintf(fmt, *cols)

      deps.each do |host, d|
        args = [fmt, host]
        args << (d.managed ? 'yes' : 'no') if fmtopts[:managed]
        args.concat([
          d.type, d.spin, d.role,
          rdomain(d.name), rdomain(d.location), rdomain(d.domain),
        ])

        puts sprintf(*args)
      end
    end

    def printf_fmt_cols
      fmts = %w(%-30s)
      cols = %w(HOST)
      managed = %w(a all).include?(opts[:managed])

      if managed
        fmts << '%-10s'
        cols << 'MANAGED'
      end

      fmts.concat(%w(%-12s %-12s %-12s %-15s %-10s %s))
      cols.concat(%w(TYPE SPIN ROLE NAME LOCATION DOMAIN))

      [fmts.join(' '), cols, {managed: managed}]
    end

    def rdomain(domain)
      domain ? domain.split('.').reverse.join('.') : nil
    end
  end
end
