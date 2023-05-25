{ config, pkgs, ... }:
let
  addr = "172.16.9.90";
in {
  cluster."cz.vpsfree/containers/prg/int.ns1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 21850;
    host = { name = "ns1"; location = "int.prg"; domain = "vpsfree.cz"; target = addr; };
    addresses = {
      v4 = [ { address = addr; prefix = 32; } ];
    };
    services = {
      bind = {};
      node-exporter = {};
      prometheus = {};
    };
    tags = [ "dns" "internal-dns" "manual-update" ];

    healthChecks = {
      builderCommands = [
        {
          command = [ "${pkgs.dnsutils}/bin/dig" "vpsfree.cz" "A" "+short" "@${addr}" ];
          standardOutput.match = "37.205.9.80\n";
        }
        {
          command = [ "${pkgs.dnsutils}/bin/dig" "node1.stg.vpsfree.cz" "A" "+short" "@${addr}" ];
          standardOutput.match = "172.16.0.66\n";
        }
        {
          command = [ "${pkgs.dnsutils}/bin/dig" "node1-mgmt.stg.vpsfree.cz" "A" "+short" "@${addr}" ];
          standardOutput.match = "172.16.101.44\n";
        }
      ];
    };
  };
}
