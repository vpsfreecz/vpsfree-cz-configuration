{ config, lib, pkgs, confData, confMachine, confLib, ... }:
let
  bpftraceGit = config.boot.kernelPackages.bpftrace.overrideAttrs (oldAttrs: rec {
    version = "0.19.git";
    src = pkgs.fetchFromGitHub {
      owner = "iovisor";
      repo = "bpftrace";
      rev = "0e231e3185ca32da453ff596bc3e0b6cbdc17342";
      sha256 = "sha256-JyMogqyntSm2IDXzsOIjcUkf2YwG2oXKpqPpdx/eMNI=";
    };
    patches = [];
  });

  rabbitmqs = map (name:
    confLib.findConfig {
      cluster = config.cluster;
      name = "cz.vpsfree/vpsadmin/int.${name}";
    }
  ) [ "rabbitmq1" "rabbitmq2" "rabbitmq3" ];
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

  boot.kernelParams = [ "slub_nomerge" "preempt=none" "iommu=off" ];

  boot.kernel.sysctl = {
    "kernel.printk" = 0;
    "net.ipv4.neigh.default.gc_thresh3" = 16384;
    "net.ipv6.neigh.default.gc_thresh3" = 16384;
    "vm.min_free_kbytes" = 16 * 1024 * 1024;
  };

  boot.extraModprobeConfig = ''
    options ixgbe allow_unsupported_sfp=1
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

    # debug stuff
    # config.boot.kernelPackages.bcc
    config.boot.kernelPackages.perf
    dstat
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
        nodeExporterCfg = config.services.prometheus.exporters.node;
        osctlExporterCfg = config.osctl.exporter;
        monitors =
          lib.filter
            (m: m.config.monitoring.isMonitor)
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

        ${lib.concatMapStringsSep "\n" (m: ''
        # node_exporter from ${m.name}
        iptables -A nixos-fw -p tcp --dport ${toString nodeExporterCfg.port} -s ${m.config.addresses.primary.address} -j nixos-fw-accept

        # osctl-exporter from ${m.name}
        iptables -A nixos-fw -p tcp --dport ${toString osctlExporterCfg.port} -s ${m.config.addresses.primary.address} -j nixos-fw-accept
        '') monitors}

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

  system.storeOverlaySize = "6G";

  services.haveged.enable = true;
}
