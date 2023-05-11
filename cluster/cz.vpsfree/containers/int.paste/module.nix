{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.paste" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 23695;
    host = { name = "paste"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.157"; prefix = 32; } ];
    };
    services = {
      node-exporter = {};
      bepasty = {};
    };
    tags = [ "auto-update" ];

    swpins.pins = {
      "nixpkgs" = {
        type = "git-rev";
        git-rev = {
          url = "https://github.com/aither64/nixpkgs";
          update.ref = "refs/heads/bepasty-1.1.0";
        };
      };
    };
  };
}
