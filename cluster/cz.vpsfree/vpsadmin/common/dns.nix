{
  config,
  pkgs,
  lib,
  confLib,
  confMachine,
  confData,
  ...
}:
let
  inherit (lib) concatMapStringsSep filter mkForce;

  allMachines = confLib.getClusterMachines config.cluster;

  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;

  exporterPort = confMachine.services.bind-exporter.port;
in
{
  environment.systemPackages = with pkgs; [
    config.services.bind.package
    dnsutils
  ];

  vpsadmin.nodectld = {
    enable = true;

    settings = {
      mode = "minimal";

      vpsadmin = {
        net_interfaces = [ "venet0" ];

        transaction_public_key = pkgs.writeText "transaction.key" ''
          -----BEGIN PUBLIC KEY-----
          MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3NbZREAR9D/24C4NK99s
          ZXfOXWXRRhwo2PFAqAeCrKD5ptZqgr4MBXPCvIhS+FgEMl5EEHqroanSYiT1M+X0
          Kn+2qXJuff+ePe3iiihjxhLxn0WxC5HI5aEigOhSfKNWnH71brMZwN6CIhrb0muh
          dEQ6CjpdRXAbP497HcnCoZ5GmWLxKrIw526aoimU3M+MoSnDvZ5eAxuXHnEVpvXc
          guSgWMYhcMTJnWUnyZR4RwmUEFSiWQ1TvjsxG94zCfr/sUtC3DrOJYqC3YPGnIhJ
          VEu0Ub2NW/uSKVhtlGGCXqhW8HCtd9+VXrpna2x6GZlLvcEMfNuMD6UJqmsfI18W
          HwIDAQAB
          -----END PUBLIC KEY-----
        '';
      };
    };
  };

  services.bind = {
    enable = true;
    directory = "/var/named";
    forwarders = mkForce [ ];
    extraOptions = ''
      recursion no;
    '';
    extraConfig = ''
      statistics-channels {
        inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
      };

      include "/var/named/vpsadmin/named.conf";
    '';
  };

  systemd.tmpfiles.rules = [
    "d '/var/named' 0750 named named - -"
  ];

  services.prometheus.exporters.bind = {
    enable = true;
    port = exporterPort;
  };

  networking.resolvconf.useLocalResolver = false;

  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  networking.firewall.extraCommands = (
    concatMapStringsSep "\n" (m: ''
      # bind-exporter from ${m.name}
      iptables -A nixos-fw -p tcp --dport ${toString exporterPort} -s ${m.metaConfig.addresses.primary.address} -j nixos-fw-accept
    '') monitors
  );
}
