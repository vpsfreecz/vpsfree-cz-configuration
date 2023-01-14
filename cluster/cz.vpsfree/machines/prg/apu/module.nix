{ config, ... }:
{
  cluster."cz.vpsfree/machines/prg/apu" = rec {
    spin = "nixos";

    # os-staging is needed to keep the channels same with the build machine, so
    # that confctl can evaluate it in one run when deploying all pxe machines.
    swpins.channels = [ "nixos-stable" "os-staging" ];

    host = { name = "apu"; location = "int.prg"; domain = "vpsfree.cz"; target = "172.16.254.254"; };
    addresses = {
      v4 = [ { address = "172.16.254.254"; prefix = 24; } ];
    };
    tags = [ "apu" "pxe" "pxe-secondary" "vpsf-status" ];
    services = {
      node-exporter = {};
      sachet = {};
    };
  };
}
