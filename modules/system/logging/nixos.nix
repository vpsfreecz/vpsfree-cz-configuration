{ lib, config, pkgs, deploymentInfo, confLib, ... }:
with lib;
let
  shared = import ./shared.nix { inherit lib config deploymentInfo confLib; };
in {
  inherit (shared) options;

  config = mkMerge [
    shared.config

    (mkIf shared.enable {
      services.SystemdJournal2Gelf = {
        enable = true;
        graylogServer = "${shared.services.graylog-gelf.address}:${toString shared.services.graylog-gelf.port}";
      };
    })
  ];
}
