{
  network.description = "vpsFree staging infrastructure";

  netboot =
    { config, lib, pkgs, ...}:
    {
      imports = [
        ../build-vpsfree-templates/files/configuration.nix
      ];

      deployment.targetHost = "172.17.4.99";
    };
  hydra =
    { config, lib, pkgs, ... }:
    {
      #deployment.targetHost = "172.16.0.7";

    };
  hydra_slave =
    { config, lib, pkgs, ... }:
    {
      #deployment.targetHost = "172.16.0.250";
    };
}
