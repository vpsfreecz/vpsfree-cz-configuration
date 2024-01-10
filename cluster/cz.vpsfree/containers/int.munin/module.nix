{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/int.munin" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 25127;
    host = { name = "munin"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.8.234"; prefix = 32; } ];
    };
    services = {
      munin-cron = {};
      node-exporter = {};
    };
    tags = [ "munin" "auto-update" ];
    healthChecks = {
      machineCommands = [
        {
          command = [ "curl" "--fail" "http://localhost" ];
          standardOutput.include = [
            "Munin"
            "</html>"
          ];
        }
      ];
    };
    swpins.pins = {
      nixpkgs = {
        type = "git-rev";
        git-rev = {
          url = "https://github.com/aither64/nixpkgs";
          update.ref = "refs/heads/munin-fastcgi";
        };
      };
    };
  };
}
