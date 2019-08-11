{ config, ... }:
{
  cluster."vpsadminos.org".global.www = rec {
    type = "container";
    spin = "nixos";
    addresses = {
      v4 = [ "37.205.14.58" ];
      v6 = [ "2a03:3b40:fe:48::1" ];
    };
    services.node-exporter = {};
  };
}
