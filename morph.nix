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
in
{
  network =  {
    pkgs = import baseSwpins.nixpkgs {};
    description = "vpsf hosts";
  };

  "build.vpsfree.cz" = deployment.osMachine {
    name = "build";
    inherit domain;
  };

  "pxe.vpsfree.cz" = deployment.osMachine {
    name = "pxe";
    inherit domain;
  };

  "vpsadminos.org" =
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

  "log.vpsfree.cz" = deployment.osContainer {
    name = "log";
    inherit domain;
  };

  "mon0.vpsfree.cz" = deployment.osContainer {
    name = "mon0";
    inherit domain;
  };

  "node1.stg.vpsfree.cz" = deployment.osNode {
    name = "node1";
    location = "stg";
    inherit domain;
  };

  "node2.stg.vpsfree.cz" = deployment.osNode {
    name = "node2";
    location = "stg";
    inherit domain;
  };

  "backuper.prg.vpsfree.cz" = deployment.osNode {
    name = "backuper";
    location = "prg";
    inherit domain;
  };
}
