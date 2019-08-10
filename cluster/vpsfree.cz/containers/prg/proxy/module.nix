{ config, ... }:
{
  cluster."vpsfree.cz".prg.proxy = rec {
    addresses = {
      v4 = [ "37.205.14.61" ];
      v6 = [ "2a03:3b40:fe:35::1" ];
    };
    services.node-exporter = {};
  };
}
