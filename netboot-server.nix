{ lib, config, pkgs, ... }:

with lib;

let
  nixpkgsSorki = (import (pkgs.fetchFromGitHub {
    owner = "sorki";
    repo = "nixpkgs";
    rev = "6ecdea467f97aa274bbaaa4944240ffd79f166c3";
    sha256 = "0b5764h1xksf13f4zkvd3ycbi72x4qhvm3sszziq650zxwcilkak";
  }) {});

  vpsadminosBuild = {modules ? []}:
    (import (pkgs.fetchFromGitHub {
      owner = "vpsfreecz";
      repo = "vpsadminos";
      rev = "a6809c0c94d81fe36ae798d998313494d6efa028";
      sha256 = "1p61pgi7rj1izwscx0398s907cgv71xq74ajc7k26gxjlmgqsf5l";
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
          "192.168.3.1" = {
            root = nginx_root;
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
