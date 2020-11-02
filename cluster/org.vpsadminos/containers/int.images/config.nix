{ config, pkgs, lib, confLib, ... }:
let
  proxy = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/proxy";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport 80 -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "images.vpsadminos.org" = {
        root = "/srv/images";
        locations = {
          "/" = {
            extraConfig = "autoindex on;";
          };
        };
      };
    };
  };
}
