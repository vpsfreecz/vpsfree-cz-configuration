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
}
