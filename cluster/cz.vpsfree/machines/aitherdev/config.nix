{
  config,
  pkgs,
  lib,
  confLib,
  confData,
  confMachine,
  swpins,
  ...
}:
let
  ns1IntPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.ns1";
  };

  ns1IntBrq = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/brq/int.ns1";
  };

  internalDns = [
    ns1IntPrg
    ns1IntBrq
  ];

  internalDnsAddresses = map (m: m.addresses.primary.address) internalDns;

  homeTmuxinator =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    with lib;
    let
      cfg = config.programs.tmux;
    in
    {
      options = {
        programs.tmux.tmuxinator = {
          projects = mkOption {
            type = types.attrsOf types.attrs;
            default = { };
            description = ''
              tmuxinator projects
            '';
          };
        };
      };

      config = mkIf (cfg.tmuxinator.enable && cfg.tmuxinator.projects != { }) {
        home.file = mapAttrs' (
          name: project:
          let
            projectPath = ".config/tmuxinator/${projectName}.yml";
            projectName = if hasName then project.name else name;
            hasName = hasAttr "name" project;
            attrs = if hasName then project else project // { inherit name; };
          in
          nameValuePair projectPath {
            text = builtins.toJSON attrs;
          }
        ) cfg.tmuxinator.projects;
      };
    };

  lxcVscode = pkgs.writeText "lxc-vscode.conf" ''
    # Distribution configuration
    lxc.include = /run/current-system/sw/share/lxc/config/common.conf
    lxc.arch = linux64

    # Container specific configuration
    lxc.rootfs.path = dir:/var/lib/lxc/vscode/rootfs
    lxc.uts.name = vscode

    # Network configuration
    lxc.net.0.type = none
    lxc.namespace.share.net = 1

    lxc.mount.entry = /etc/resolv.conf etc/resolv.conf none bind,create=file 0 0
    lxc.mount.entry = /etc/ssh/authorized_keys.d/aither etc/ssh/authorized_keys.d/aither none bind,create=file 0 0
    lxc.mount.entry = /home/aither/workspace home/aither/workspace none bind,create=dir 0 0
  '';
in
{
  # NOTE: environments/base.nix is not imported, this is a standalone system
  imports = [
    ./hardware.nix
    "${builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz"}/nixos"
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.useDHCP = false;

  networking.bridges.br0.interfaces = [ "enp1s0" ];
  networking.interfaces.br0.ipv4.addresses = [
    {
      address = "172.16.106.40";
      prefixLength = 24;
    }
  ];

  # Network for PXE development
  networking.interfaces.enp8s0.ipv4.addresses = [
    {
      address = "192.168.100.10";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = "172.16.106.1";
  networking.nameservers = internalDnsAddresses ++ [ "172.16.106.1" ];

  nix = {
    nixPath = [ "nixpkgs=${swpins.nixpkgs}" ];

    settings = {
      sandbox = true;
      extra-sandbox-paths = [
        "/secrets=/home/aither/workspace/vpsadmin/vpsadminos/os/secrets?"
      ];
      trusted-users = [ "aither" ];
      substituters = [ "https://cache.vpsadminos.org" ];
      trusted-public-keys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
      fallback = true;
      connect-timeout = 10;
    };
  };

  nixpkgs.overlays = import ../../../../overlays;

  time.timeZone = "Europe/Amsterdam";

  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  users.users.root.openssh.authorizedKeys.keys =
    confData.sshKeys.builders ++ confData.sshKeys.aither.all;

  users.users.aither = {
    isNormalUser = true;
    homeMode = "711";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = confData.sshKeys.aither.all;
  };

  environment.systemPackages = with pkgs; [
    vim
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  services.postfix.enable = true;

  security.sudo = {
    enable = true;
    extraRules = [
      {
        groups = [ "wheel" ];
        commands = [ "ALL" ];
      }
    ];
    extraConfig = ''
      Defaults:aither timestamp_timeout=90
    '';
  };

  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  programs.bepastyrb.enable = true;

  # Bridge for VMs
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.bridges.virbr0.interfaces = [ ];
  networking.interfaces.virbr0.ipv4.addresses = [
    {
      address = "192.168.122.1";
      prefixLength = 24;
    }
  ];

  networking.firewall.allowedTCPPorts = [
    # For vpsfree-web
    80

    # vscode container
    2222
  ];

  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i virbr0 -p udp -m udp --dport 53 -j ACCEPT
    iptables -A nixos-fw -i virbr0 -p tcp -m tcp --dport 53 -j ACCEPT
    iptables -A nixos-fw -i virbr0 -p udp -m udp --dport 67 -j ACCEPT
    iptables -A nixos-fw -i virbr0 -p tcp -m tcp --dport 67 -j ACCEPT
    iptables -A nixos-fw -i virbr0 -p udp -m udp --dport 68 -j ACCEPT
    iptables -A nixos-fw -i virbr0 -p tcp -m tcp --dport 68 -j ACCEPT

    # vpsAdmin API dev server
    iptables -A nixos-fw -p tcp -m tcp --dport 4567 -s 172.16.106.0/24 -j ACCEPT
    iptables -A nixos-fw -p tcp -m tcp --dport 4567 -s 172.16.107.0/24 -j ACCEPT

    # vpsf-status
    iptables -A nixos-fw -p tcp -m tcp --dport 8080 -s 172.16.106.0/24 -j ACCEPT
    iptables -A nixos-fw -p tcp -m tcp --dport 8080 -s 172.16.107.0/24 -j ACCEPT

    # socket network for vpsAdminOS test-runner
    iptables -A nixos-fw -m pkttype --pkt-type multicast -p udp --dport 10000:30000 -j ACCEPT

    iptables -t nat -A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE
  '';

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = "virbr0";
      listen-address = "192.168.122.1";
      bind-interfaces = true;
      dhcp-option = [
        "3,192.168.122.1" # gateway
        "6,192.168.122.1" # dns servers
      ];
      dhcp-range = "192.168.122.100,192.168.122.200,255.255.255.0,24h";
      dhcp-leasefile = "/var/lib/dnsmasq/dnsmasq.leases";
      dhcp-authoritative = true;
    };
  };

  environment.etc."qemu/bridge.conf".text = ''
    allow br0
    allow virbr0
  '';

  environment.homeBinInPath = true;

  home-manager.users.aither =
    { config, ... }:
    {
      imports = [
        homeTmuxinator
      ];

      programs.home-manager.enable = true;

      home.stateVersion = "23.11";

      home.packages = with pkgs; [
        asciinema
        bind
        bundix
        cloc
        codex
        git
        go
        inetutils
        nix-prefetch-git
        openssl
        php
        ruby
        screen
        tmux
        tree
        unzip
        vpsfree-client
      ];

      home.file = {
        ".gitconfig".text = ''
          [user]
            name = Jakub Skokan
            email = jakub.skokan@havefun.cz

          [push]
            default = current
        '';

        "bin/dev-shell" = {
          text = ''
            #!/usr/bin/env bash
            # Run nix-shell with custom prompt
            SHELL_PROMPT="\n\[\033[1;35m\][nix-shell:\w]\$\[\033[0m\] "
            export PROMPT_COMMAND="export PS1=\"$SHELL_PROMPT\"; unset PROMPT_COMMAND"
            exec nix-shell "$@"
          '';
          executable = true;
        };
      };

      programs.bash = {
        enable = true;
        historySize = 10000;
        historyFileSize = 10000;
        initExtra = ''
          export PS1="\n\[\033[1;35m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
        '';
      };

      programs.tmux = {
        enable = true;
        extraConfig = ''
          set -g mouse on
          setw -g mode-keys vi
        '';

        tmuxinator = {
          enable = true;
          projects = {
            vpsadminos-nodes = {
              root = "~/workspace/vpsf-dev";
              windows = [
                { build = "./vpsadminos-shell"; }
                {
                  qemu = {
                    layout = "tiled";
                    panes = [
                      "./vpsadminos-shell"
                      "./vpsadminos-shell"
                      "# ssh root@172.16.106.41"
                      "# ssh root@172.16.106.42"
                      "# ssh root@172.16.106.41"
                      "# ssh root@172.16.106.42"
                    ];
                  };
                }
              ];
            };

            vpsadminos-dev = {
              root = "~/workspace/vpsf-dev";
              windows = [
                {
                  repo = {
                    layout = "tiled";
                    panes = [
                      "./vpsadminos-shell"
                      "./vpsadminos-shell"
                    ];
                  };
                }
              ];
            };

            vpsadmin-dev = {
              root = "~/workspace/vpsf-dev";
              windows = [
                {
                  repo = {
                    layout = "tiled";
                    panes = [
                      "./vpsadmin-shell"
                      "./vpsadmin-shell"
                    ];
                  };
                }

                {
                  api-mgmt = {
                    layout = "tiled";
                    panes = [
                      "./vpsadmin-api-shell"
                      "./vpsadmin-api-shell"
                    ];
                  };
                }

                {
                  api-servers = {
                    layout = "tiled";
                    panes = [
                      "./vpsadmin-api-shell"
                      "./vpsadmin-api-shell"
                    ];
                  };
                }

                { webui = "cd ~/workspace/vpsadmin/vpsadmin/webui; dev-shell"; }

                { console = "cd ~/workspace/vpsadmin/vpsadmin/console_router ; dev-shell"; }

                { vnc = "cd ~/workspace/vpsadmin/vpsadmin/vnc_router ; dev-shell"; }
              ];
            };

            nixos-conf = {
              root = "~/workspace";
              windows = [
                { vpsfree-cz-configuration = "cd vpsfree.cz/vpsfree-cz-configuration ; dev-shell"; }
                { vpsadminos-org-configuration = "cd nixos/vpsadminos-org-configuration"; }
                { confctl = "cd confctl ; dev-shell"; }
              ];
            };

            pxe-dev = {
              root = "~";
              windows = [
                {
                  deploy = {
                    layout = "tiled";
                    panes = [
                      "cd ~/workspace/confctl ; dev-shell"
                      "cd ~/workspace/pxe-cluster ; dev-shell"
                    ];
                  };
                }
                { pxe-server = "# ssh root@192.168.100.5"; }
              ];
            };
          };
        };
      };
    };

  containers.vpsfree-web = {
    autoStart = true;
    bindMounts = {
      "/vpsfree-web" = {
        hostPath = "/home/aither/workspace/vpsfree.cz/web";
        isReadOnly = true;
      };
    };
    config =
      { config, ... }:
      {
        imports = [
          ../../../../modules/services/vpsfree-web.nix
        ];

        services.vpsfree-web = {
          enable = true;
          virtualHosts = {
            "web-cs.aitherdev.int.vpsfree.cz" = {
              web = "/vpsfree-web";
              language = "cs";
            };

            "web-en.aitherdev.int.vpsfree.cz" = {
              web = "/vpsfree-web";
              language = "en";
            };
          };
        };
      };
  };

  virtualisation.lxc.enable = true;

  # Steps to recreate the container:
  #
  #  - lxc-create -n vscode -t download -- --dist debian --release bookworm --arch amd64
  #  - rm /var/lib/lxc/vscode/config
  #  - systemctl start lxc-vscode
  #  - lxc-attach -n vscode
  #  - . /etc/profile ; . /etc/profile
  #  - apt-get install git nix openssh-server unattended-upgrades
  #  - edit /etc/ssh/sshd_config:
  #      Port 2222
  #      AuthorizedKeysFile %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
  #  - useradd -u 1000 -g users -d /home/aither aither
  #  - chmod 0711 /home/aither
  #
  systemd.services.lxc-vscode = {
    description = "Auto-start LXC container vscode";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lxc}/bin/lxc-start -F -f ${lxcVscode} -n vscode";
      ExecStop = "${pkgs.lxc}/bin/lxc-stop -n vscode";
      Type = "simple";
    };
    restartIfChanged = false;
  };

  system.stateVersion = "23.11";
}
