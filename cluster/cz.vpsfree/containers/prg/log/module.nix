{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/log" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-19.03" "os-master" ];
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
