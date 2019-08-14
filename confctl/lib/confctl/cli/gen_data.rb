require 'highline/import'
require 'vpsfree/client'

module ConfCtl::Cli
  class GenData < Command
    DATADIR = File.join(ConfCtl.root, 'data')

    def all
      network
    end

    def network
      network_containers
    end

    def network_containers
      api = get_client
      networks = api.network.list
      data = {}

      [4, 6].each do |ip_v|
        data["ipv#{ip_v}"] = networks.select { |net| net.ip_version == ip_v }.map do |net|
          {address: net.address, prefix: net.prefix}
        end
      end

      nixer = ConfCtl::Nixer.new(data)
      update_file('networks/containers.nix') do |f|
        f.puts(nixer.serialize)
      end
    end

    protected
    def get_client
      return @api if @api
      @api = VpsFree::Client.new

      user = ask('User name: ') { |q| q.default = nil }.to_s
      password = ask('Password: ') do |q|
        q.default = nil
        q.echo = false
      end.to_s

      @api.authenticate(:basic, user: user, password: password)
      @api
    end

    def update_file(relpath)
      abs = File.join(DATADIR, relpath)
      tmp = "#{abs}.new"

      File.open(tmp, 'w') { |f| yield(f) }
      File.rename(tmp, abs)
    end
  end
end
