{ config, pkgs, lib, confLib, confData, confMachine, ... }:
with lib;
let
  rsyslogTcpPort = confMachine.services.rsyslog-tcp.port;
  rsyslogUdpPort = confMachine.services.rsyslog-udp.port;

  loggedAddresses = filter (a:
    a.metaConfig.logging.enable
  ) (confLib.getAllAddressesOf config.cluster 4);

  allMachines = confLib.getClusterMachines config.cluster;

  getAlias = host: "${host.name}${optionalString (!isNull host.location) ".${host.location}"}";

  syslogExporterHosts = listToAttrs (map (m: nameValuePair m.name {
    alias = getAlias m.metaConfig.host;
    fqdn = m.metaConfig.host.fqdn;
    os = m.metaConfig.spin;
  }) allMachines);

  syslogExporterPort = confMachine.services.syslog-exporter.port;

  monitorings = filter (d: d.metaConfig.monitoring.isMonitor) allMachines;

  reloadRsyslog = ''
    kill -HUP `systemctl show --property MainPID --value syslog`
  '';
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
        # Allow access from ${a.metaConfig.host.fqdn} @ ${a.address}
        iptables -A nixos-fw -p tcp -s ${a.address} --dport ${toString rsyslogTcpPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${a.address} --dport ${toString rsyslogUdpPort} -j nixos-fw-accept
      '') loggedAddresses}

      ### Syslog-exporter
      ${concatStringsSep "\n" (map (d: ''
        # Allow access to syslog-exporter from ${d.metaConfig.host.fqdn}
        iptables -A nixos-fw -p tcp -m tcp -s ${d.metaConfig.addresses.primary.address} --dport ${toString syslogExporterPort} -j nixos-fw-accept
      '') monitorings)}
    '';
  };

  services.rsyslogd = {
    enable = true;
    defaultConfig = mkForce ''
      template(name="remote-log-file" type="string" string="/var/log/remote/%HOSTNAME%/log")

      ruleset(name="remote-file"){
        action(type="omfile" dynaFile="remote-log-file")
        call remote-pipe
      }

      ruleset(name="remote-pipe") {
        action(type="ompipe" Pipe="${config.services.prometheus.confExporters.syslog.settings.syslog_pipe}")
      }

      module(load="imtcp")
      input(type="imtcp" port="11514" ruleset="remote-file")

      module(load="imudp")
      input(type="imudp" port="11515" ruleset="remote-file")

      *.*             -/var/log/messages
      *.*             |${config.services.prometheus.confExporters.syslog.settings.syslog_pipe}
    '';
  };

  services.prometheus.confExporters.syslog = {
    enable = true;
    port = syslogExporterPort;
    settings = {
      hosts = syslogExporterHosts;
    };
  };

  services.logrotate = {
    enable = true;
    settings = {
      nodes = {
        files = [
          "/var/log/remote/cz.vpsfree/nodes/*/*/log"

          # This file contains logs sent by svlogd from all nodes. They all
          # appear as if from localhost, the node fqdn is a part of the message...
          "/var/log/remote/localhost/log"
        ];
        frequency = "daily";
        rotate = 180;
        dateext = true;
        notifempty = true;
        nocompress = true;
        postrotate = reloadRsyslog;
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
        postrotate = reloadRsyslog;
      };

      containers = {
        files = [
          "/var/log/messages"
          "/var/log/remote/cz.vpsfree/containers/*/log"
          "/var/log/remote/cz.vpsfree/containers/*/*/log"
          "/var/log/remote/cz.vpsfree/vpsadmin/*/log"
        ];
        frequency = "monthly";
        rotate = 13;
        dateext = true;
        notifempty = true;
        nocompress = true;
        postrotate = reloadRsyslog;
      };

      others = {
        files = [
          # Mikrotik routers
          "/var/log/remote/MAI-*/log"
        ];
        frequency = "monthly";
        rotate = 13;
        dateext = true;
        notifempty = true;
        nocompress = true;
        maxsize = "512M";
        postrotate = reloadRsyslog;
      };
    };
  };

  system.stateVersion = "22.05";
}
