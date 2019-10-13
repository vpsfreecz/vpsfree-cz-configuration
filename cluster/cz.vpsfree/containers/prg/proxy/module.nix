{ config, ... }:
{
  cluster."cz.vpsfree".prg.proxy = rec {
    type = "container";
    spin = "nixos";
    container.id = 14096;
    addresses = {
      v4 = [ { address = "37.205.14.61"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:fe:35::1"; prefix = 64; } ];
    };
    services.node-exporter = {};
  };
}
