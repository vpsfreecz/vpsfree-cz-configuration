{ config, ... }:
{
  cluster."vpsfree.cz".prg.log = rec {
    type = "container";
    spin = "nixos";
    container.id = 14004;
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
