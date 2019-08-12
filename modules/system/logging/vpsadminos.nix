{ lib, config, pkgs, deploymentInfo, confLib, ... }:
with lib;
let
  shared = import ./shared.nix { inherit lib config deploymentInfo confLib; };
in {
  inherit (shared) options;

  config = mkMerge [
    shared.config

    (mkIf shared.enable {
      services.rsyslogd.forward = [
        "${shared.services.graylog-rsyslog-tcp.address}:${toString shared.services.graylog-rsyslog-tcp.port}"
      ];
    })
  ];
}
