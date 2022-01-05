{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.log" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 14004;
    host = { name = "log"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.4.1"; prefix = 32; };
    logging.isLogger = true;
    services = {
      graylog-gelf = {};
      graylog-http = {};
      graylog-rsyslog-tcp = {};
      graylog-rsyslog-udp = {};
      node-exporter = {};
    };
  };
}
