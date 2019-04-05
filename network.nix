{
  network.description = "vpsFree infrastructure";

  netboot =
    { config, lib, pkgs, ...}:
    {
      imports = [
        ./env.nix
        ./machines/netboot-server.nix
      ];
    };
}
