{ config, pkgs, lib, confLib, data, ... }:
let
  proxy = confLib.findConfig {
    cluster = config.cluster;
    domain = "org.vpsadminos";
    location = null;
    name = "proxy";
  };

  images = import ../../../../lib/images.nix { inherit config data lib confLib pkgs; };

  isoImages = [ images.vpsadminosISO ];

  isoRoot = pkgs.runCommand "isoroot" {} ''
    mkdir $out
    for iso in ${lib.concatStringsSep " " isoImages}; do
      fpath=$iso/iso/*.iso
      name=$( basename $fpath )
      ln -s $fpath $out/$name
      sha256sum $fpath > $out/$name.sha256
    done
  '';
in {
  imports = [
    ../../../../environments/base.nix
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
      "iso.vpsadminos.org" = {
        root = isoRoot;
        locations = {
          "/" = {
            extraConfig = "autoindex on;";
          };
        };
      };
    };
  };
}
