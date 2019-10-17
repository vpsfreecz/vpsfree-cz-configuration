{ config, pkgs, lib, confLib, data, ... }:
{
  imports = [
    ../../../../environments/base.nix
  ];

  environment.systemPackages = with pkgs; [
    git
    gnumake
  ];

  services.buildbot-worker = {
    enable = true;
    masterUrl = "172.16.4.20:9989";
    workerUser = "nixos02";
    workerPassFile = "/private/buildbot/worker/pass";
  };

  nix = {
    binaryCaches = [ "https://cache.vpsadminos.org" ];
    binaryCachePublicKeys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
  };
}
