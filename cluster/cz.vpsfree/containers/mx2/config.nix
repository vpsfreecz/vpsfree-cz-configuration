{
  pkgs,
  lib,
  config,
  confData,
  ...
}:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../../../configs/mx2.nix
  ];

  networking = {
    nameservers = lib.mkForce [ "1.1.1.1" ];
    firewall = {
      enable = true;
      allowedTCPPorts = lib.mkForce [ 22 ];
      extraCommands = ''
        iptables -A nixos-fw -p tcp -s 172.16.106.40/32 --dport 25 -j nixos-fw-accept
      '';
    };
  };

  users.users.root.openssh.authorizedKeys.keys = with confData.sshKeys; [
    toms
    aither.aitherdev
  ];

  system.stateVersion = "25.05";
}
