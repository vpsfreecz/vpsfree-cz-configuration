{
  lib,
  config,
  pkgs,
  confMachine,
  confLib,
  ...
}:
with lib;
let
  shared = import ./shared.nix {
    inherit
      lib
      config
      confMachine
      confLib
      ;
  };
in
{
  inherit (shared) options;

  config = mkMerge [
    shared.config

    (mkIf shared.enable {
      services.rsyslogd = {
        enable = true;
        extraConfig = ''
          $LocalHostName ${confMachine.name}

          *.* @@${shared.services.rsyslog-tcp.address}:${toString shared.services.rsyslog-tcp.port};RSYSLOG_SyslogProtocol23Format
        '';
      };
    })
  ];
}
