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
  hydra =
    { config, lib, pkgs, ... }:
    {
      imports = [
        ./env.nix
        ./hydra-master.nix
      ];
    };
  hydra_slave =
    { config, lib, pkgs, ... }:
    {
      imports = [
        ./env.nix
        ./hydra-slave.nix
      ];
    };
}
