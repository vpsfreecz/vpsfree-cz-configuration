{ config, pkgs, lib, confLib, confData, confMachine, ... }:
with lib;
let
  rsyslogTcpPort = confMachine.services.rsyslog-tcp.port;
  rsyslogUdpPort = confMachine.services.rsyslog-udp.port;

  loggedAddresses = filter (a:
    a.config.logging.enable
  ) (confLib.getAllAddressesOf config.cluster 4);

  allMachines = confLib.getClusterMachines config.cluster;

  getAlias = host: "${host.name}${optionalString (!isNull host.location) ".${host.location}"}";

  syslogExporterHosts = listToAttrs (map (m: nameValuePair m.name {
    alias = getAlias m.config.host;
    fqdn = m.config.host.fqdn;
    os = m.config.spin;
  }) allMachines);

  syslogExporterPort = confMachine.services.syslog-exporter.port;

  monitorings = filter (d: d.config.monitoring.isMonitor) allMachines;
in {
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
  ];

  networking.firewall = {
    extraCommands = ''
      ### Management networks
      ${concatMapStringsSep "\n" (net: ''
        # Allow access from ${net.location} @ ${net.address}/${toString net.prefix}
        iptables -A nixos-fw -p tcp -s ${net.address}/${toString net.prefix} --dport ${toString rsyslogTcpPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${net.address}/${toString net.prefix} --dport ${toString rsyslogUdpPort} -j nixos-fw-accept
      '') confData.vpsadmin.networks.management.ipv4}

      ## DHCP networks
      ${concatMapStringsSep "\n" (net: ''
        # Allow access from ${net.location} @ ${net.address}/${toString net.prefix}
        iptables -A nixos-fw -p tcp -s ${net.address}/${toString net.prefix} --dport ${toString rsyslogTcpPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${net.address}/${toString net.prefix} --dport ${toString rsyslogUdpPort} -j nixos-fw-accept
      '') confData.vpsadmin.networks.management.dhcp}

      ### Individual machines
      ${concatMapStringsSep "\n" (a: ''
        # Allow access from ${a.config.host.fqdn} @ ${a.address}
        iptables -A nixos-fw -p tcp -s ${a.address} --dport ${toString rsyslogTcpPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${a.address} --dport ${toString rsyslogUdpPort} -j nixos-fw-accept
      '') loggedAddresses}

      ### Syslog-exporter
      ${concatStringsSep "\n" (map (d: ''
        # Allow access to syslog-exporter from ${d.config.host.fqdn}
        iptables -A nixos-fw -p tcp -m tcp -s ${d.config.addresses.primary.address} --dport ${toString syslogExporterPort} -j nixos-fw-accept
      '') monitorings)}
    '';
  };

  services.rsyslogd = {
    enable = true;
    extraConfig = ''
      module(load="imtcp")
      input(type="imtcp" port="11514")

      $template remote-incoming-logs, "/var/log/remote/%HOSTNAME%/log"
      *.* ?remote-incoming-logs

      *.* |${config.services.syslog-exporter.settings.syslog_pipe}
    '';
  };

  services.syslog-exporter = {
    enable = true;
    settings = {
      port = syslogExporterPort;
      hosts = syslogExporterHosts;
    };
  };

  services.logrotate = {
    enable = true;
    settings = {
      nodes = {
        files = [ "/var/log/remote/cz.vpsfree/nodes/*/*/log" ];
        frequency = "daily";
        rotate = 180;
        dateext = true;
        notifempty = true;
        nocompress = true;
        postrotate = ''
          kill -HUP `cat /run/rsyslog.pid`
        '';
      };

      machines = {
        files = [
          "/var/log/remote/cz.vpsfree/machines/*/log"
          "/var/log/remote/cz.vpsfree/machines/*/*/log"
        ];
        frequency = "monthly";
        rotate = 13;
        dateext = true;
        notifempty = true;
        nocompress = true;
        postrotate = ''
          kill -HUP `cat /run/rsyslog.pid`
        '';
      };

      containers = {
        files = [
          "/var/log/remote/cz.vpsfree/containers/*/log"
          "/var/log/remote/cz.vpsfree/containers/*/*/log"
          "/var/log/remote/cz.vpsfree/vpsadmin/*/log"
        ];
        frequency = "monthly";
        rotate = 13;
        dateext = true;
        notifempty = true;
        nocompress = true;
        postrotate = ''
          kill -HUP `cat /run/rsyslog.pid`
        '';
      };

      others = {
        files = [ "/var/log/remote/*/log" ];
        frequency = "monthly";
        rotate = 13;
        dateext = true;
        notifempty = true;
        nocompress = true;
        maxsize = "512M";
        postrotate = ''
          kill -HUP `cat /run/rsyslog.pid`
        '';
      };
    };
  };

  system.stateVersion = "22.05";
}
