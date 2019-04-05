{
  network.description = "vpsFree infrastructure";

  netboot =
    { config, lib, pkgs, ...}:
    {
      imports = [
        ./env.nix
        ./netboot-server.nix
      ];
    };
}
