{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.bb.master" = rec {
    spin = "nixos";
    container.id = 14570;
    host = { name = "master.bb.int"; domain = "vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.20"; prefix = 32; };
    services = {
      buildbot-master = {};
      node-exporter = {};
    };
    monitoring.enable = false;
  };
}
