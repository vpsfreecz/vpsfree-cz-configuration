let
  shared = [
    ./cluster
    ./programs/havesnippet.nix
    ./services/definitions.nix
    ./system/monitoring.nix
  ];

  nixos = [
    ./clusterconf/alerter
    ./clusterconf/monitor
    ./services/monitoring/prometheus/rules.nix
    ./services/sachet.nix
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
