module DiscoverNetbootable
  # Generate `cluster/netbootable.nix` with a list of all netbootable nodes
  class Script < ConfCtl::UserScript
    register

    def setup_hooks(hooks)
      hooks.subscribe(:configuration_rediscover) do
        machines =
          ConfCtl::MachineList.new.select do |_host, machine|
            machine['netboot.enable'] && !machine.carried?
          end.map do |host, _machine|
            host
          end

        dst = 'cluster/netbootable.nix'
        puts "replace #{dst}"

        File.open(dst, 'w') do |f|
          f.puts('# This file is auto-generated on confctl rediscover, changes will be lost')
          f.write(ConfCtl::NixFormat.to_nix(machines))
        end
      end
    end
  end
end
