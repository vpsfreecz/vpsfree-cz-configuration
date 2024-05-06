let
  shared = [
    ./cluster
    ./programs/bepastyrb.nix
    ./services/definitions.nix
    ./system/monitoring.nix
    ./vpsfconf/admins.nix
  ];

  nixos = [
    ./clusterconf/alerter
    ./clusterconf/monitor
    ./services/geminabox/gc.nix
    ./services/geminabox/server.nix
    ./services/monitoring/prometheus/conf-exporters/ssh.nix
    ./services/monitoring/prometheus/conf-exporters/syslog.nix
    ./services/monitoring/prometheus/rules.nix
    ./services/network-graphs
    ./services/sachet.nix
    ./services/vpsf-status.nix
    ./services/vpsfree-irc-bot.nix
    ./system/logging/nixos.nix
  ];

  vpsadminos = [
    ./system/logging/vpsadminos.nix
    ./system/serial-console.nix
  ];
in {
  nixos = shared ++ nixos;
  vpsadminos = shared ++ vpsadminos;
}
