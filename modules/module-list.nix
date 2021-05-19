let
  shared = [
    ./programs/havesnippet.nix
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
    ./configs/node.nix
    ./system/logging/vpsadminos.nix
  ];
in {
  nixos = shared ++ nixos;
  vpsadminos = shared ++ vpsadminos;
}
