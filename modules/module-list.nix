let
  shared = [
    ./programs/havesnippet.nix
    ./system/monitoring.nix
  ];

  nixos = [
    ./services/netboot.nix
    ./services/sachet.nix
    ./services/vpsadminos-web.nix
  ];

  vpsadminos = [];
in {
  nixos = shared ++ nixos;
  vpsadminos = shared ++ vpsadminos;
}
