{ pkgs, lib, config, confLib, confData, ... }:
{
  vpsadmin.database = {
    enable = true;

    defaultConfig = false;

    allowedIPv4Ranges =
      let
        management = map (net:
          "${net.address}/${toString net.prefix}"
        ) confData.vpsadmin.networks.management.ipv4;

        others = [
          "37.205.8.141/32" # utils.vpsfree.cz
        ];
      in management ++ others;
  };
}
