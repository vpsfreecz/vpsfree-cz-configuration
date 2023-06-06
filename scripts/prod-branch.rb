# Reconfigure branch used on production nodes
#
# The switch consists of:
#   - updating channel name in configs/swpins.nix
#   - updating channel name in cluster/.../module.nix
#   - running confctl swpins channel update <new-branch> vpsadminos
#   - removing old swpins file in swpins/channels/
#
# The user still has to update nixpkgs and vpsadmin swpins to his liking.
module ProdBranch
  class Script < ConfCtl::UserScript
    register

    def setup_cli(app)
      app.desc 'Switch prod branch'
      app.arg_name '<new-branch>'
      app.command 'set-prod-branch' do |c|
        c.action &ConfCtl::Cli::Command.run(c, Command, :switch_branch)
      end
    end
  end

  class Command < ConfCtl::Cli::Cluster
    def switch_branch
      require_args!('new-branch')

      new_branch = args[0]

      unless new_branch.start_with?('prod-')
        fail "Prod branch must start with 'prod-', e.g. 'prod-23.05'"
      end

      machines = ConfCtl::MachineList.new.select do |_, m|
        m.spin == 'vpsadminos' && m['swpins']['channels'].detect { |v| v.start_with?('prod-') }
      end

      old_branch = nil

      machines.each do |host, machine|
        branch = machine['swpins']['channels'].first

        if old_branch.nil?
          old_branch = branch
        elsif old_branch != branch
          fail "Found conflicting old branches: #{old_branch} and #{branch}; can replace just one"
        end
      end

      ask_confirmation! do
        puts "The following machines will be reconfigured:"
        print_changes(machines, new_branch)
        puts
        puts "Channel #{old_branch} will be removed."
      end

      git_add = []

      puts 'Updating configs/swpins.nix'
      git_add << 'configs/swpins.nix'
      sed!("s/\"#{old_branch}\"/\"#{new_branch}\"/", 'configs/swpins.nix')

      machines.each do |host, machine|
        machine_module = File.join('cluster', host, 'module.nix')
        puts "Updating #{machine_module}"
        sed!("s/\"#{old_branch}\"/\"#{new_branch}\"/", machine_module)
        git_add << machine_module
      end

      puts 'Updating swpins'
      confctl!('swpins', 'channel', 'update', new_branch, 'vpsadminos')

      new_swpin = File.join('swpins', 'channels', "#{new_branch}.json")
      git_add << new_swpin
      run!('git', 'add', new_swpin)

      old_swpin = File.join('swpins', 'channels', "#{old_branch}.json")

      puts "Removing #{old_swpin}"
      begin
        File.unlink(old_swpin)
        git_add << old_swpin
      rescue Errno::ENOENT
      end

      puts 'Commiting'
      run!(
        'git', 'commit', '-m', "Switch over nodes from #{old_branch} to #{new_branch}",
        *git_add,
      )
    end

    protected
    def print_changes(machines, new_branch)
      rows = []

      machines.each do |host, machine|
        rows << {
          name: host,
          current_channel: machine['swpins']['channels'].first,
          new_channel: new_branch,
        }
      end

      ConfCtl::Cli::OutputFormatter.print(
        rows,
        %i(name current_channel new_channel),
        layout: :columns,
      )
    end

    def sed!(expression, file)
      run!('sed', '-i', expression, file)
    end

    def confctl!(*args)
      run!('confctl', *args)
    end

    def run!(*args)
      unless Kernel.system(*args)
        fail "Command #{args.join(' ')} failed"
      end
    end
  end
end
