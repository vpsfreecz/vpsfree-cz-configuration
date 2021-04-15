{ lib, config, pkgs, confMachine, confLib, ... }:
with lib;
let
  shared = import ./shared.nix { inherit lib config confMachine confLib; };
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
