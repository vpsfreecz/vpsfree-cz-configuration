{
  config,
  pkgs,
  confLib,
  confData,
  confMachine,
  flakeInputs,
  inputsInfo,
  inputs,
  ...
}:
let
  homeManagerInput = inputsInfo."home-manager".input;
  llmAgentsInput = inputsInfo."llm-agents".input;
  llmAgentsPkgs = flakeInputs.${llmAgentsInput}.packages.${pkgs.stdenv.hostPlatform.system};

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

  codexLbImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/soju06/codex-lb";
    imageDigest = "sha256:1e192a4be352199c4062ff472129c896ad33c31fc4c17c77cf637c7c640d0a23";
    sha256 = "sha256-t4jWU737htc8XYbFurohL2+sci34jqh/cOHzsWoHtUk=";
    finalImageName = "ghcr.io/soju06/codex-lb";
    finalImageTag = "1.20.0-beta.2";
  };

  codexDeepseekResponsesProxy = pkgs.writeTextFile {
    name = "codex-deepseek-responses-proxy";
    destination = "/bin/codex-deepseek-responses-proxy";
    executable = true;
    text = builtins.readFile ../../../../packages/codex-deepseek-responses-proxy/proxy.py;
    checkPhase = ''
      ${pkgs.python3}/bin/python3 -m py_compile "$target"
    '';
  };

  codexDs = pkgs.writeShellScriptBin "codex-ds" ''
    exec ${llmAgentsPkgs.codex}/bin/codex -p ds "$@"
  '';

  codexDsConfig = pkgs.writeText "codex-ds.config.toml" ''
    model_provider = "deepseek"
    model = "deepseek-v4-pro"
    model_reasoning_effort = "high"
    model_supports_reasoning_summaries = true

    [model_providers.deepseek]
    name = "DeepSeek via local Responses proxy"
    base_url = "http://127.0.0.1:4141"
    experimental_bearer_token = "local-codex-deepseek"
    wire_api = "responses"
  '';
in
{
  # NOTE: environments/base.nix is not imported, this is a standalone system
  imports = [
    ./hardware.nix
    flakeInputs.${homeManagerInput}.nixosModules.home-manager
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
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    settings = {
      sandbox = true;
      extra-sandbox-paths = [
        "/secrets=/home/aither/workspace/vpsadmin/vpsadminos/os/secrets?"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "aither" ];
      substituters = [ "https://cache.vpsadminos.org" ];
      trusted-public-keys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
      fallback = true;
      connect-timeout = 10;
    };
  };

  systemd.services.nix-store-gc-on-pressure = {
    description = "Garbage-collect the Nix store when disk usage is high";
    path = [
      config.nix.package
      pkgs.coreutils
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      usage=$(df --output=pcent /nix/store | tail -n 1 | tr -dc '0-9')

      if [ -z "$usage" ]; then
        echo "Unable to determine /nix/store disk usage" >&2
        exit 1
      fi

      if [ "$usage" -lt 75 ]; then
        echo "/nix/store usage is $usage%, below threshold"
        exit 0
      fi

      echo "/nix/store usage is $usage%, running Nix garbage collection"
      nix-collect-garbage
    '';
  };

  systemd.timers.nix-store-gc-on-pressure = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "15min";
      RandomizedDelaySec = "5min";
    };
  };

  systemd.services.codex-deepseek-responses-proxy = {
    description = "Codex DeepSeek Responses API proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      DEEPSEEK_API_KEY_FILE = "/home/aither/.codex/deepseek-key";
      DEEPSEEK_BASE_URL = "https://api.deepseek.com";
      DEEPSEEK_PROXY_API_KEY = "local-codex-deepseek";
      DEEPSEEK_PROXY_STATE_DIR = "/var/lib/codex-deepseek-responses-proxy";
    };
    serviceConfig = {
      Type = "simple";
      User = "aither";
      Group = "users";
      ExecStart = "${pkgs.python3}/bin/python3 ${codexDeepseekResponsesProxy}/bin/codex-deepseek-responses-proxy --host 127.0.0.1 --port 4141";
      Restart = "on-failure";
      RestartSec = "2s";
      StateDirectory = "codex-deepseek-responses-proxy";
      StateDirectoryMode = "0700";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
    };
  };

  system.activationScripts.codexDeepseekProfile.text = ''
    profile=/home/aither/.codex/ds.config.toml

    if [ -L "$profile" ] || [ ! -e "$profile" ]; then
      install -d -m 0700 -o aither -g users /home/aither/.codex
      rm -f "$profile"
      install -m 0600 -o aither -g users ${codexDsConfig} "$profile"
    fi
  '';

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

  environment.systemPackages =
    (with pkgs; [
      vim
    ])
    ++ [
      llmAgentsPkgs.codex
    ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  services.postfix.enable = true;

  services.samba = {
    enable = true;
    openFirewall = false;
    nmbd.enable = false;
    winbindd.enable = false;
    settings = {
      global = {
        "hosts allow" = [ "172.16.107.34" ];
        "hosts deny" = [ "0.0.0.0/0" ];
        "disable netbios" = "yes";
      };
      workspace = {
        path = "/home/aither/workspace";
        comment = "aither workspace";
        browseable = "yes";
        "read only" = "no";
        "valid users" = [ "aither" ];
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

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

  programs.mosh = {
    enable = true;
    openFirewall = false;
    package = pkgs.mosh-osc-colors;
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."codex-lb.aitherdev.int.vpsfree.cz" = {
      listen = [
        {
          addr = "172.16.106.40";
          port = 80;
        }
      ];
      locations = {
        "= /v1".return = "403";
        "^~ /v1/".return = "403";
        "= /backend-api/codex".return = "403";
        "^~ /backend-api/codex/".return = "403";
        "= /backend-api/transcribe".return = "403";
        "^~ /backend-api/transcribe/".return = "403";
        "/" = {
          proxyPass = "http://127.0.0.1:2455";
          proxyWebsockets = true;
        };
      };
    };
  };

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

    # codex-lb dashboard over WireGuard
    iptables -A nixos-fw -p tcp -m tcp --dport 80 -s 172.16.107.0/24 -j ACCEPT

    # Samba workspace share
    iptables -A nixos-fw -p tcp -m tcp --dport 445 -s 172.16.107.34/32 -j ACCEPT

    # mosh
    iptables -A nixos-fw -p udp -m udp --dport 60000:61000 -s 172.16.106.0/24 -j ACCEPT
    iptables -A nixos-fw -p udp -m udp --dport 60000:61000 -s 172.16.107.0/24 -j ACCEPT

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

  security.wrappers.qemu-bridge-helper = {
    source = "${pkgs.qemu_kvm}/libexec/qemu-bridge-helper";
    owner = "root";
    group = "wheel";
    setuid = true;
    permissions = "u+rx,g+rx,o-rx";
  };

  environment.homeBinInPath = true;

  home-manager.users.aither =
    { config, ... }:
    let
      mkNixosConfWindow =
        name: path:
        let
          cmd = "cd ${path} ; nix develop";
        in
        {
          ${name} = {
            layout = "tiled";
            panes = [
              cmd
              cmd
            ];
          };
        };
    in
    {
      programs.home-manager.enable = true;

      home.stateVersion = "23.11";

      home.packages = with pkgs; [
        asciinema
        bat
        bind
        bundix
        cloc
        codexDs
        curl
        fd
        file
        gh
        git
        go
        gnumake
        inetutils
        jq
        nix-prefetch-git
        openssl
        php
        python3
        ripgrep
        ruby
        screen
        tmux
        tree
        unzip
        vpsfree-client
        wget
        which
        zip
      ];

      home.file = {
        ".gitconfig".text = ''
          [user]
            name = Jakub Skokan
            email = jakub.skokan@havefun.cz

          [push]
            default = current
        '';
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
        terminal = "tmux-256color";
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

                { webui = "cd ~/workspace/vpsadmin/vpsadmin/webui; nix develop"; }

                { console = "cd ~/workspace/vpsadmin/vpsadmin/console_router ; nix develop"; }
              ];
            };

            vpsf-status = {
              root = "~/workspace/vpsf-status";
              windows = [
                {
                  repo = {
                    layout = "tiled";
                    panes = [
                      "nix develop"
                      "nix develop"
                    ];
                  };
                }
              ];
            };

            terraform-provider-vpsadmin = {
              root = "~/workspace/vpsadmin/terraform-provider-vpsadmin";
              windows = [
                {
                  repo = {
                    layout = "tiled";
                    panes = [
                      "nix develop"
                      "nix develop"
                    ];
                  };
                }
              ];
            };

            nixos-conf = {
              root = "~/workspace";
              windows = [
                (mkNixosConfWindow "vpsfree-cz-configuration" "vpsfree.cz/vpsfree-cz-configuration")
                (mkNixosConfWindow "vpsadminos-org-configuration" "nixos/vpsadminos-org-configuration")
                (mkNixosConfWindow "havefun-cz-configuration" "nixos/havefun-cz-configuration")
                (mkNixosConfWindow "zima-engineering-configuration" "nixos/zima-engineering-configuration")
                (mkNixosConfWindow "confctl" "confctl")
              ];
            };

            pxe-dev = {
              root = "~";
              windows = [
                {
                  deploy = {
                    layout = "tiled";
                    panes = [
                      "cd ~/workspace/confctl ; nix develop"
                      "cd ~/workspace/pxe-cluster ; nix develop"
                    ];
                  };
                }
                { pxe-server = "# ssh root@192.168.100.5"; }
              ];
            };

            haveapi-dev = {
              root = "~/workspace/haveapi/haveapi";
              windows = [
                {
                  repo = {
                    layout = "tiled";
                    panes = [
                      "nix develop"
                      "nix develop"
                    ];
                  };
                }

                { servers-ruby = "cd ~/workspace/haveapi/haveapi/servers/ruby; nix develop"; }

                { clients-ruby = "cd ~/workspace/haveapi/haveapi/clients/ruby ; nix develop"; }

                { clients-php = "cd ~/workspace/haveapi/haveapi/clients/php ; nix develop"; }

                { clients-js = "cd ~/workspace/haveapi/haveapi/clients/js ; nix develop"; }

                { clients-go = "cd ~/workspace/haveapi/haveapi/clients/go ; nix develop"; }
              ];
            };
          };
        };
      };
    };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.codex-lb = {
      image = "ghcr.io/soju06/codex-lb:1.20.0-beta.2";
      imageFile = codexLbImage;
      ports = [
        "127.0.0.1:2455:2455"
        "127.0.0.1:1455:1455"
      ];
      volumes = [
        "codex-lb-data:/var/lib/codex-lb"
      ];
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
