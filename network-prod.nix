{
  network.description = "vpsFree infrastructure";

  netboot =
    { config, lib, pkgs, ...}:
    {
      imports = [
        ../build-vpsfree-templates/files/configuration.nix
      ];

      deployment.targetHost = "172.16.8.1";

      netboot.host = "boot.vpsadminos.org";
      netboot.acmeSSL = true;

      web.acmeSSL = true;
    };
}
