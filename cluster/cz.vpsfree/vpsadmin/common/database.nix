{ pkgs, lib, config, confLib, confData, ... }:
let
  api1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api1";
  };

  api2 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api2";
  };

  vpsadmin1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.vpsadmin1";
  };

  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  utils = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.utils";
  };
in {
  vpsadmin.database = {
    enable = true;

    defaultConfig = false;

    allowedIPv4Ranges =
      let
        management = map (net:
          "${net.address}/${toString net.prefix}"
        ) confData.vpsadmin.networks.management.ipv4;

        others = [
          "${api1.addresses.primary.address}/32"
          "${api2.addresses.primary.address}/32"
          "${vpsadmin1.addresses.primary.address}/32"
          "${proxyPrg.addresses.primary.address}/32"
          "${utils.addresses.primary.address}/32"
        ];
      in management ++ others;
  };
}
