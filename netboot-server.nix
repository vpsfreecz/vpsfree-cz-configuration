{ lib, config, pkgs, ... }:

with lib;

let
  nixpkgsSorki = (import (pkgs.fetchFromGitHub {
    owner = "sorki";
    repo = "nixpkgs";
    rev = "0acf57c45cee013652edb3dd1db9c76d42c2f858";
    sha256 = "1x9m05ng52hd7haiy8n5rl5h1504afh8nqxv0959y1csi117g0bm";
  }) {});

  vpsadminosBuild = {modules ? []}:
    (import (pkgs.fetchFromGitHub {
      owner = "vpsfreecz";
      repo = "vpsadminos";
      rev = "29a1bdf61f364a7cfb4a292353bd780c6b3e90ac";
      sha256 = "0mi09bqyfriqcxmda5d0c19qywm68kpx4avcv28ckw24b7smqcam";
    } + "/os/" )  {
      nixpkgs = nixpkgsSorki.path;
      system = "x86_64-linux";
      extraModules = modules;
    }).config.system.build;

  netboot = let
    build = (import (pkgs.path + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = [
        (pkgs.path + "/nixos/modules/installer/netboot/netboot-minimal.nix")
      ];
    }).config.system.build;
  in pkgs.symlinkJoin {
    name = "netboot";
    paths = with build; [ netbootRamdisk kernel netbootIpxeScript ];
  };

  node = {modules ? []}:
    pkgs.symlinkJoin {
      name = "netboot_node";
      paths = with vpsadminosBuild {}; [ dist ];
    };

  # stock vpsadminos
  vpsadminos = node { modules = []; };

  # node configurations
  node1 = node {
    modules = [ {

      imports = [
        ./env.nix
        ./nodes/node1.nix
      ];

    } ];
  };

  node2 = node {
    modules = [ {

      imports = [
        ./env.nix
        ./nodes/node2.nix
      ];

    } ];
  };

  tftp_root = pkgs.runCommand "tftproot" {} ''
    mkdir -pv $out
    cp -vi ${pkgs.ipxe}/undionly.kpxe $out/undionly.kpxe
  '';

  nginx_root = pkgs.runCommand "nginxroot" {} ''
    mkdir -pv $out
    cat <<EOF > $out/boot.php
    #!ipxe
    chain netboot/netboot.ipxe
    EOF
    ln -sv ${netboot} $out/netboot
    ln -sv ${vpsadminos} $out/netboot_vpsadminos
    ln -sv ${node1} $out/netboot_node_1
    ln -sv ${node2} $out/netboot_node_2
  '';
  cfg = config.netboot_server;
in {
  options = {
    netboot_server = {
      network.wan = mkOption {
        type = types.str;
        description = "the internet facing IF";
        default = "wlan0";
      };
      network.lan = mkOption {
        type = types.str;
        description = "the netboot client facing IF";
        default = "enp9s0";
      };
    };
  };
  config = {
    services = {
      nginx = {
        enable = true;
        virtualHosts = {
          "boot.vpsfree.cz" = {
            default = true;
            root = nginx_root;
            locations = {
              "/" = {
                extraConfig = "autoindex on;";
              };
            };
          };
        };
      };
      tftpd = {
        enable = true;
        path = tftp_root;
      };
    };
  };
}
