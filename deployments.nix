let
  baseSwpins = import ./swpins rec {
    name = "base";
    pkgs = (import <nixpkgs> {});
    lib = pkgs.lib;
  };

  deployment = import ./lib/deployment.nix rec {
    pkgs = import baseSwpins.nixpkgs {};
    lib = pkgs.lib;
  };

  domain = "vpsfree.cz";

  nameValuePairs = list: map (v: { name = v.fqdn; value = v; }) list;

  mkDeployments = list: builtins.listToAttrs (nameValuePairs list);
in mkDeployments [

  ### Nodes
  ## Prague
  # backuper.prg
  (deployment.osNode {
    name = "backuper";
    location = "prg";
    inherit domain;
    netboot = {
      enable = true;
      macs = [
        "00:25:90:2f:a3:ac"
        "00:25:90:2f:a3:ad"
        "00:25:90:2f:a3:ae"
        "00:25:90:2f:a3:af"
      ];
    };
  })

  ## Staging
  # node1.stg
  (deployment.osNode {
    name = "node1";
    location = "stg";
    inherit domain;
    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:30:76:18"
        "0c:c4:7a:30:76:19"
        "0c:c4:7a:30:76:1a"
        "0c:c4:7a:30:76:1b"
      ];
    };
  })

  # node2.stg
  (deployment.osNode {
    name = "node2";
    location = "stg";
    inherit domain;
    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:ab:b4:43"
        "0c:c4:7a:ab:b4:42"
      ];
    };
  })

  ### Support machines
  # build.vpsfree.cz
  (deployment.osMachine {
    name = "build";
    inherit domain;
  })

  # pxe.vpsfree.cz
  (deployment.nixosMachine {
    name = "pxe";
    inherit domain;
  })

  ### Containers
  # vpsadminos.org
  (deployment.custom rec {
    type = "vz";
    name = "www";
    domain = "vpsadminos.org";
    config =
      { config, pkgs, ... }:
        let
          legacy = import ./swpins rec {
            name = "legacy";
            pkgs = (import <nixpkgs> {});
            lib = pkgs.lib;
          };
        in {
          deployment = {
            nixPath = [
              { prefix = "nixpkgs"; path = legacy.nixpkgs; }
            ];
          };

          imports = [
            ./containers/vpsadminos.org/www.nix
            "${legacy.build-vpsfree-templates}/files/configuration.nix"
          ];
        };
  })

  # log.vpsfree.cz
  (deployment.osContainer {
    name = "log";
    inherit domain;
  })

  # mon0.vpsfree.cz
  (deployment.osContainer {
    name = "mon0";
    inherit domain;
  })
]
