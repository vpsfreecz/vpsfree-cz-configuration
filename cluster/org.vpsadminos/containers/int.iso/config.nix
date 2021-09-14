{ config, pkgs, lib, confDir, confLib, confData, ... }:
let
  proxy = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/proxy";
  };

  images = import ../../../../lib/images.nix {
    inherit config lib pkgs confDir confLib confData;
  };

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
