{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/log" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-19.03" ];
    swpins.pins = {
      vpsadminos = {
        type = "git-rev";

        git-rev = {
          url = "https://github.com/vpsfreecz/vpsadminos";
          update.ref = "41a176a346ff92ab14e6f46519947035ef9973d0";
        };
      };
    };
    container.id = 14004;
    host = { name = "log"; location = "prg"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.4.1"; prefix = 32; };
    logging.isLogger = true;
    services = {
      graylog-gelf = {};
      graylog-rsyslog-tcp = {};
      graylog-rsyslog-udp = {};
      node-exporter = {};
    };
  };
}
