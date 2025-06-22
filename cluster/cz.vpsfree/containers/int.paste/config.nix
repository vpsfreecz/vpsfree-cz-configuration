{ config, pkgs, lib, confLib, confMachine, ... }:
with lib;
let
  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access from proxy.prg
    iptables -A nixos-fw -p tcp --dport ${toString confMachine.services.bepasty.port} -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  services.bepasty = {
    enable = true;
    servers."paste.vpsfree.cz" = {
      bind = "0.0.0.0:${toString confMachine.services.bepasty.port}";

      defaultPermissions = "read,create";

      extraConfig = ''
        MAX_ALLOWED_FILE_SIZE = 16 * 1024 * 1024

        PERMISSIONS = {}

        import json
        with open('/private/bepasty/permissions.json', 'r') as f:
            PERMISSIONS = json.load(f)
      '';

      secretKeyFile = "/private/bepasty/secret-key.txt";
    };
  };

  systemd.services."bepasty-server-paste.vpsfree.cz-gunicorn".preStart = ''
    rm -f "${config.services.bepasty.servers."paste.vpsfree.cz".workDir}/gunicorn-paste.vpsfree.cz.pid"
  '';

  system.stateVersion = "22.11";
}
