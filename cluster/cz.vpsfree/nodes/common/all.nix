{ config, lib, pkgs, data, deploymentInfo, confLib, ...}:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../configs/munin-node.nix
  ];

  users.users.root.initialHashedPassword = "$6$X/q70eX.dr$svzVWUFXbcOwEtPtURVVy0n80evQMXxI4fU7ICBG5xXftWSuZh4G4zSQ8FF9mgICLfwxzFTffFcXluhn0xazH.";

  boot.kernelModules = [
    "ipmi_si"
    "ipmi_devintf"
    "ipip"
    "ip_gre"
    "wireguard"
  ];

  boot.extraModulePackages =
    lib.optional (lib.versionOlder config.boot.kernelPackages.kernel.version "5.6") config.boot.kernelPackages.wireguard;
  boot.kernel.sysctl = {
    "net.ipv4.neigh.default.gc_thresh3" = 16384;
    "net.ipv6.neigh.default.gc_thresh3" = 16384;
  };

  boot.extraModprobeConfig = "options zfs zfs_arc_min=34359738368";

  vpsadminos.nix = true;
  environment.systemPackages = with pkgs; [
    dmidecode
    # Constantly broken
    # ipmicfg
    lm_sensors
    pciutils
    smartmontools
    usbutils
    iotop
    ledmon
    git
    ethtool

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

  nixpkgs.overlays = import ../../../../overlays;

  networking = {
    firewall.extraCommands =
      let
        nodeCfg = deploymentInfo.config;
        nfsCfg = config.services.nfs.server;
        nodeExporterCfg = config.services.prometheus.exporters.node;
        osctlExporterCfg = config.osctl.exporter;
        monPrg = confLib.findConfig {
          cluster = config.cluster;
          domain = "cz.vpsfree";
          location = "prg";
          name = "int.mon";
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
        iptables -A nixos-fw -p tcp --dport ${toString nfsCfg.nfsd.port} -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport ${toString nfsCfg.nfsd.port} -j nixos-fw-accept

        # mountd
        iptables -A nixos-fw -p tcp --dport ${toString nfsCfg.mountdPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport ${toString nfsCfg.mountdPort} -j nixos-fw-accept

        # statd
        iptables -A nixos-fw -p tcp --dport ${toString nfsCfg.statdPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport ${toString nfsCfg.statdPort} -j nixos-fw-accept

        # lockd
        iptables -A nixos-fw -p tcp --dport ${toString nfsCfg.lockdPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp --dport ${toString nfsCfg.lockdPort} -j nixos-fw-accept

        # iperf
        iptables -A nixos-fw -p tcp --dport 5001 -j nixos-fw-accept

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
    nfsd.port = 2049;
    mountdPort = 20048;
    statdPort = 662;
    lockdPort = 32769;
  };

  osctl.exporter.enable = true;

  services.openssh = {
    openFirewall = false;
    extraConfig = ''
      Match Address 172.16.0.0/12
        PasswordAuthentication yes
        PermitRootLogin yes
    '';
  };

  osctl.exportfs.enable = true;

  vpsadmin.enable = true;
  vpsadmin.transactionPublicKeyFile = pkgs.writeText "transaction.key" ''
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
}
