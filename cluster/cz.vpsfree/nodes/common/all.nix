{ config, lib, pkgs, confData, confMachine, confLib, ... }:
let
  bpftraceGit = config.boot.kernelPackages.bpftrace.overrideAttrs (oldAttrs: rec {
    version = "0.21.2";
    src = pkgs.fetchFromGitHub {
      owner = "bpftrace";
      repo = "bpftrace";
      rev = "93c593f6dab2e930d6198cfaa52b29d19a8c0647";
      sha256 = "sha256-/2m+5iFE7R+ZEc/VcgWAhkLD/jEK88roUUOUyYODi0U=";
    };
    patches = [];
  });

  rabbitmqs = map (name:
    confLib.findMetaConfig {
      cluster = config.cluster;
      name = "cz.vpsfree/vpsadmin/int.${name}";
    }
  ) [ "rabbitmq1" "rabbitmq2" "rabbitmq3" ];

  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  modprobeWrapper = pkgs.writeScript "modprobe-wrapper.sh" ''
    #!/bin/sh
    echo "$@" | ${pkgs.util-linux}/bin/logger -t kernel.modprobe
    exec ${pkgs.kmod}/bin/modprobe "$@"
  '';
in
{
  imports = [
    <vpsadmin/nixos/modules/vpsadminos-modules.nix>
    ../../../../environments/base.nix
    ../../../../configs/node
    ../../../../configs/munin-node.nix
    ../../vpsadmin/common/settings.nix
  ];

  users.users.root.initialHashedPassword = "$y$j9T$WXTPc7ms74FZcj6c7HDOO/$bAOvRUTPg8ClT5RX2pqHWezXXJM82khUZVmwxaumbpD";

  boot.kernelModules = [
    "ipmi_si"
    "ipmi_devintf"
  ];

  boot.extraModulePackages =
    lib.optional (lib.versionOlder config.boot.kernelPackages.kernel.version "5.6") config.boot.kernelPackages.wireguard;

  boot.kernelParams = [ "slub_nomerge" "preempt=none" "iommu=off" "cgroup_favordynmods=false" ];

  boot.kernel.sysctl = {
    "kernel.modprobe" = "${modprobeWrapper}";
    "kernel.printk" = 0;
    "net.ipv4.neigh.default.gc_thresh3" = 16384;
    "net.ipv6.neigh.default.gc_thresh3" = 16384;
  };

  boot.extraModprobeConfig = ''
    options ixgbe allow_unsupported_sfp=1
  '';

  environment.interactiveShellInit = ''
    alias arcstat='arcstat -f time,hits,miss,mtxmis,grow,need,c,size,free'
  '';

  environment.systemPackages = with pkgs; [
    bpftraceGit
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
    kexec-tools

    # debug stuff
    # config.boot.kernelPackages.bcc
    config.boot.kernelPackages.perf
    dool
    strace

    wireguard-tools
  ];

  # to be able to include ipmicfg
  nixpkgs.config.allowUnfree = true;

  os.channel-registration.enable = false;

  networking = {
    firewall.checkReversePath = false;

    firewall.extraCommands =
      let
        nodeCfg = confMachine;
        nfsCfg = config.services.nfs.server;
        monitors =
          lib.filter
            (m: m.metaConfig.monitoring.isMonitor)
            (confLib.getClusterMachines config.cluster);
        sshCfg = config.services.openssh;
        sshRules = map (port:
          "iptables -A nixos-fw -p tcp --dport ${toString port} -j nixos-fw-accept"
        ) sshCfg.ports;
        managementNetworks = confData.vpsadmin.networks.management.ipv4;
        vpsadminSendRecvRules = map (net: ''
          # ${net.location}
          iptables -A nixos-fw -p tcp -s ${net.address}/${toString net.prefix} --dport 10000:20000 -j nixos-fw-accept
        '') managementNetworks;
      in ''
        # sshd
        ${lib.concatStringsSep "\n" sshRules}

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

        # goresheat from VPN
        iptables -A nixos-fw -p tcp -s 172.16.107.0/24 --dport ${toString config.services.goresheat.port} -j nixos-fw-accept

        # goresheat from proxy
        iptables -A nixos-fw -p tcp -s ${proxyPrg.addresses.primary.address} --dport ${toString config.services.goresheat.port} -j nixos-fw-accept

        # vpsadmin ports for zfs send/recv
        ${lib.concatStringsSep "\n" vpsadminSendRecvRules}

        ${lib.optionalString (lib.hasAttr "vpsadmin-console" nodeCfg.services) ''
        # vpsadmin remote console
        iptables -A nixos-fw -p tcp -s 172.16.9.140 --dport ${toString nodeCfg.services.vpsadmin-console.port} -j nixos-fw-accept
        ''}
      '';
  };

  services.zfs.autoScrub.enable = false;

  services.nfs.server = {
    enable = true;
    nfsd.port = 2049;
    mountdPort = 20048;
    statdPort = 662;
    lockdPort = 32769;
  };

  osctld.settings = {
    debug = true;
    send_receive = {
      send_mbuffer = {
        block_size = "128k";
        buffer_size = "512M";
        start_writing_at = 5;
      };
      receive_mbuffer = {
        block_size = "128k";
        buffer_size = "1024M";
        start_writing_at = 80;
      };
    };
  };

  # Workaround for a bug in kernel which causes node_exporter to get stuck
  # while reading power info from /sys.
  #
  # This is known to happen on node21.prg and node22.prg.
  #
  # /proc/pid/stack reads as:
  # [<0>] show_power+0x34/0x100 [acpi_power_meter]
  # [<0>] dev_attr_show+0x19/0x40
  # [<0>] sysfs_kf_seq_show+0xbe/0x160
  # [<0>] seq_read_iter+0x11c/0x4b0
  # [<0>] new_sync_read+0x115/0x1a0
  # [<0>] vfs_read+0x14b/0x1a0
  # [<0>] ksys_read+0x5f/0xe0
  # [<0>] do_syscall_64+0x33/0x40
  # [<0>] entry_SYSCALL_64_after_hwframe+0x44/0xa9
  #
  # Related to these paths:
  #   /sys/class/hwmon/hwmon9
  #   /sys/bus/acpi/drivers/power_meter
  #   /sys/devices/LNXSYSTM:00/LNXSYBUS:00/ACPI000D:00
  #
  services.prometheus.exporters.node.disabledCollectors = [ "hwmon" ];

  services.goresheat = {
    enable = true;
    port = confMachine.services.goresheat.port;
    url = "https://goresheat.vpsfree.cz/${confMachine.host.fqdn}";
  };

  services.openssh = {
    openFirewall = false;
    extraConfig = ''
      Match Address 172.16.0.0/12
        PasswordAuthentication yes
        PermitRootLogin yes
    '';
  };

  osctl.exportfs.enable = true;

  vpsadmin.nodectld = {
    enable = true;
    settings = {
      vpsadmin = {
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

  system.secretsDir = "/secrets/nodes/images/${confMachine.host.fqdn}/secrets";

  system.storeOverlaySize = "10G";

  services.irqbalance.enable = true;

  services.haveged.enable = true;
}
