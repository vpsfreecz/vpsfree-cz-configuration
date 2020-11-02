{ config, pkgs, lib, confLib, ... }:
let
  proxy = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/proxy";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      9989
    ];

    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport ${toString config.services.buildbot-master.port} -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };


  environment.systemPackages = with pkgs; [
    git
  ];

  services.buildbot-master = {
    enable = true;
    masterCfg = ./master.cfg.py;
    port = config.serviceDefinitions.buildbot-master.port;
  };
}
