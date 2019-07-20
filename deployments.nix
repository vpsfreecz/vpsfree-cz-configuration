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
  (deployment.osMachine {
    name = "build";
    inherit domain;
  })

  (deployment.nixosMachine {
    name = "pxe";
    inherit domain;
  })

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
          imports = [
            ./containers/vpsadminos.org/www.nix
            "${legacy.build-vpsfree-templates}/files/configuration.nix"
          ];

          deployment = {
            nixPath = [
              { prefix = "nixpkgs"; path = legacy.nixpkgs; }
            ];
            healthChecks = {
              http = [
                {
                  scheme = "http";
                  port = 80;
                  path = "/";
                  description = "Check whether nginx is running.";
                }
                {
                  scheme = "https";
                  port = 443;
                  host = "vpsadminos.org";
                  path = "/";
                  description = "vpsadminos.org is up";
                }
              ];
            };
          };
        };
  })

  (deployment.osContainer {
    name = "log";
    inherit domain;
  })

  (deployment.osContainer {
    name = "mon0";
    inherit domain;
  })

  (deployment.osNode {
    name = "node1";
    location = "stg";
    inherit domain;
  })

  (deployment.osNode {
    name = "node2";
    location = "stg";
    inherit domain;
  })

  (deployment.osNode {
    name = "backuper";
    location = "prg";
    inherit domain;
  })
]
