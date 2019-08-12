{ config, lib, pkgs, data, deploymentInfo, confLib, ...}:
{
  imports = [
    ../../../environments/base.nix
  ];

  users.users.root.initialHashedPassword = "$6$bdENLP5gkTO$iVMOmBo4EmmP2YawSOHEvMlq1WDn9RvMCG3ChYfpBoYKejAIz/g78EP2gfE8zM2SdS8p3O8E2LbzQMXwOupdj/";

  boot.kernelModules = [
    "ipmi_si"
    "ipmi_devintf"
  ];

  boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];
  boot.kernel.sysctl = {
    "net.ipv4.neigh.default.gc_thresh3" = 16384;
    "net.ipv6.neigh.default.gc_thresh3" = 16384;
  };

  boot.extraModprobeConfig = "options zfs zfs_arc_min=34359738368";

  vpsadminos.nix = true;
  environment.systemPackages = with pkgs; [
    dmidecode
    ipmicfg
    lm_sensors
    pciutils
    smartmontools
    usbutils
    iotop
    ledmon

    # debug stuff
    # config.boot.kernelPackages.bcc
    config.boot.kernelPackages.bpftrace
    config.boot.kernelPackages.perf
    dstat
    strace

    wireguard
    wireguard-tools
  ];

  # to be able to include ipmicfg
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = import ../../../overlays;

  networking = {
    firewall.extraCommands =
      let
        nodeCfg = deploymentInfo.config;
        nfsCfg = config.services.nfs.server;
        nodeExporterCfg = config.services.prometheus.exporters.node;
        osctlExporterCfg = config.osctl.exporter;
        monPrg = confLib.findConfig {
          cluster = config.cluster;
          domain = "vpsfree.cz";
          location = "prg";
          name = "mon.int";
        };
        sshCfg = config.services.openssh;
        sshRules = map (port:
          "iptables -A nixos-fw -p tcp --dport ${toString port} -j nixos-fw-accept"
        ) sshCfg.ports;
        managementNetworks = data.networks.management.ipv4;
        vpsadminSendRecvRules = map (net: ''
          # ${net.location}
          iptables -A nixos-fw -p tcp -s ${net.address}/${toString net.prefix} --dport 10000:20000 -j nixos-fw-accept
        '') managementNetworks;
      in ''
        # sshd
        ${lib.concatStringsSep "\n" sshRules}

        # node_exporter
        iptables -A nixos-fw -p tcp --dport ${toString nodeExporterCfg.port} -s ${monPrg.addresses.primary.address} -j nixos-fw-accept

        # osctl-exporter
        iptables -A nixos-fw -p tcp --dport ${toString osctlExporterCfg.port} -s ${monPrg.addresses.primary.address} -j nixos-fw-accept

        # rpcbind
        iptables -A nixos-fw -p tcp --dport 111 -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport 111 -j nixos-fw-accept

        # nfsd
        iptables -A nixos-fw -p tcp --dport 2049 -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport 2049 -j nixos-fw-accept

        # mountd
        iptables -A nixos-fw -p tcp --dport ${toString nfsCfg.mountdPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport ${toString nfsCfg.mountdPort} -j nixos-fw-accept

        # statd
        iptables -A nixos-fw -p tcp --dport ${toString nfsCfg.statdPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport ${toString nfsCfg.statdPort} -j nixos-fw-accept

        # lockd
        iptables -A nixos-fw -p tcp --dport ${toString nfsCfg.lockdPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport ${toString nfsCfg.lockdPort} -j nixos-fw-accept

        # vpsadmin ports for zfs send/recv
        ${lib.concatStringsSep "\n" vpsadminSendRecvRules}

        ${lib.optionalString (lib.hasAttr "vpsadmin-console" nodeCfg.services) ''
        # vpsadmin remote console
        iptables -A nixos-fw -p tcp -s 172.16.8.5 --dport ${toString nodeCfg.services.vpsadmin-console.port} -j nixos-fw-accept
        ''}
      '';
  };

  services.nfs.server = {
    enable = true;
    mountdPort = 20048;
    statdPort = 662;
    lockdPort = 32769;
  };

  services.prometheus.exporters.node = {
    enable = true;
    extraFlags = [ "--collector.textfile.directory=/run/metrics" ];
  };
  osctl.exporter.enable = true;
  services.rsyslogd.forward = [ "172.16.4.1:11514" ];
  services.openssh = {
    openFirewall = false;
    extraConfig = ''
      Match Address 172.16.0.0/12
        PasswordAuthentication yes
        PermitRootLogin yes
    '';
  };

  vpsadmin.enable = true;
  system.secretsDir = toString /secrets/image/secrets;

  programs.bash.promptInit = ''
    # Provide a nice prompt if the terminal supports it.
    if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
      PROMPT_COLOR="1;31m"
      let $UID && PROMPT_COLOR="1;32m"
      PS1="\n\[\033[$PROMPT_COLOR\][\u@\H:\w]\\$\[\033[0m\] "
      if test "$TERM" = "xterm"; then
        PS1="\[\033]2;\h:\u:\w\007\]$PS1"
      fi
    fi
  '';

  programs.havesnippet.enable = true;

  services.haveged.enable = true;

  osctl.pools.tank = {
    parallelStart = 2;
    parallelStop = 4;
  };

  environment.etc =
  let prefix = "/secrets/nodes/${ config.networking.hostName }/ssh";
      path = pkgs.copyPathToStore prefix;
  in
  {
    "ssh/ssh_host_rsa_key.pub".source = "${ path }/ssh_host_rsa_key.pub";
    "ssh/ssh_host_rsa_key" = { mode = "0600"; source = "${ path }/ssh_host_rsa_key"; };
    "ssh/ssh_host_ed25519_key.pub".source = "${ path }/ssh_host_ed25519_key.pub";
    "ssh/ssh_host_ed25519_key" = { mode = "0600"; source = "${ path }/ssh_host_ed25519_key"; };
  };
}
