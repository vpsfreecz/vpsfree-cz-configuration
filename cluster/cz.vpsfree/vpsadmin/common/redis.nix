{ pkgs, lib, config, confLib, ... }:
let
  webui1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui1";
  };

  webui2 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui2";
  };
in {
  vpsadmin.redis = {
    enable = true;

    passwordFile = "/private/vpsadmin-redis.pw";

    allowedIPv4Ranges = [
      "${webui1.addresses.primary.address}/32"
      "${webui2.addresses.primary.address}/32"
    ];
  };
}
