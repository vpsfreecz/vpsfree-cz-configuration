{ config, pkgs, lib, confLib, data, ... }:
{
  imports = [
    ../../../../environments/base.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      8010 9989
    ];
  };

  environment.systemPackages = with pkgs; [
    git
  ];

  services.buildbot-master = {
    enable = true;
    masterCfg = ./master.cfg.py;
  };
}
