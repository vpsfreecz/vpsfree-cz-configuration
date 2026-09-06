{
  config,
  lib,
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
  workspacePortalHost = "vpsfree-cz.workspace.aitherdev.int.vpsfree.cz";
  workspacePortalLegacyHost = "vpsfree-cz-workspace.aitherdev.int.vpsfree.cz";
  workspacePortalWildcard = "*.workspace.aitherdev.int.vpsfree.cz";
  workspacePortalPassword = "/var/lib/vpsfree-workspace-portal-password/password";
  workspacePortalAuth = "/var/lib/vpsfree-workspace-portal-auth/htpasswd";
  workspacePkiState = "/var/lib/vpsfree-workspace-pki";
  workspacePortalTls = "/var/lib/vpsfree-workspace-portal-tls";
  workspacePortalPublicCa = "/var/lib/vpsfree-workspace-portal-public/ca.pem";
  workspacePortalRouterSocket = "/run/vpsfree-workspace-router/router.sock";
  workspacePortalRouterDir = builtins.dirOf workspacePortalRouterSocket;
  workspacePortalReconcile = pkgs.writeShellApplication {
    name = "workspace-portal-substrate-reconcile";
    runtimeInputs = with pkgs; [
      apacheHttpd
      coreutils
      gnugrep
      openssl
      util-linux
    ];
    text = ''
      set -euo pipefail
      umask 077
      exec 9>/run/lock/vpsfree-workspace-portal-substrate.lock
      flock 9

      password_file=${lib.escapeShellArg workspacePortalPassword}
      auth_file=${lib.escapeShellArg workspacePortalAuth}
      pki_state=${lib.escapeShellArg workspacePkiState}
      tls_dir=${lib.escapeShellArg workspacePortalTls}
      public_ca=${lib.escapeShellArg workspacePortalPublicCa}
      canonical=${lib.escapeShellArg workspacePortalHost}
      wildcard=${lib.escapeShellArg workspacePortalWildcard}
      legacy=${lib.escapeShellArg workspacePortalLegacyHost}
      authority="$pki_state/authority"
      ca_key="$authority/ca-key.pem"
      ca_cert="$authority/ca.pem"

      install -d -o root -g workspace-portal-owner -m 0750 "$(dirname "$password_file")"
      if [ ! -e "$password_file" ]; then
        password_tmp=$(mktemp "$(dirname "$password_file")/.password.XXXXXX")
        openssl rand -hex 32 > "$password_tmp"
        chown root:workspace-portal-owner "$password_tmp"
        chmod 0640 "$password_tmp"
        mv -T "$password_tmp" "$password_file"
      fi
      if [ -L "$password_file" ] || [ ! -f "$password_file" ] ||
         [ "$(stat -c '%U:%G:%a' "$password_file")" != "root:workspace-portal-owner:640" ] ||
         [ "$(wc -c < "$password_file")" -ne 65 ] ||
         ! grep -Eq '^[0-9a-f]{64}$' "$password_file"; then
        echo "invalid workspace portal password file: $password_file" >&2
        exit 1
      fi

      install -d -o root -g nginx -m 0750 "$(dirname "$auth_file")"
      auth_tmp=$(mktemp "$(dirname "$auth_file")/.htpasswd.XXXXXX")
      htpasswd -niBC 12 aither < "$password_file" > "$auth_tmp"
      # shellcheck disable=SC2016
      grep -Eq '^aither:\$2[aby]\$12\$[./A-Za-z0-9]{53}$' "$auth_tmp"
      chown root:nginx "$auth_tmp"
      chmod 0640 "$auth_tmp"
      mv -T "$auth_tmp" "$auth_file"

      install -d -o root -g root -m 0700 "$pki_state"
      if [ ! -e "$authority" ]; then
        authority_tmp=$(mktemp -d "$pki_state/.authority.XXXXXX")
        trap 'rm -rf -- "$authority_tmp"' EXIT INT TERM
        openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
          -out "$authority_tmp/ca-key.pem"
        openssl req -x509 -new -sha256 -days 3650 \
          -key "$authority_tmp/ca-key.pem" \
          -subj '/CN=vpsFree.cz Workspace Development CA' \
          -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
          -addext 'keyUsage=critical,keyCertSign,cRLSign' \
          -addext 'subjectKeyIdentifier=hash' \
          -out "$authority_tmp/ca.pem"
        chown root:root "$authority_tmp" "$authority_tmp/ca-key.pem" "$authority_tmp/ca.pem"
        chmod 0700 "$authority_tmp"
        chmod 0600 "$authority_tmp/ca-key.pem"
        chmod 0644 "$authority_tmp/ca.pem"
        openssl verify -CAfile "$authority_tmp/ca.pem" "$authority_tmp/ca.pem" >/dev/null
        mv -T "$authority_tmp" "$authority"
        trap - EXIT INT TERM
      fi
      if [ -L "$authority" ] || [ ! -d "$authority" ] ||
         [ -L "$ca_key" ] || [ -L "$ca_cert" ] ||
         [ ! -f "$ca_key" ] || [ ! -f "$ca_cert" ]; then
        echo "incomplete or unsafe workspace CA state" >&2
        exit 1
      fi
      chown root:root "$ca_key" "$ca_cert"
      chmod 0600 "$ca_key"
      chmod 0644 "$ca_cert"
      openssl verify -CAfile "$ca_cert" "$ca_cert" >/dev/null
      ca_key_public=$(openssl pkey -in "$ca_key" -pubout -outform DER | openssl dgst -sha256)
      ca_cert_public=$(openssl x509 -in "$ca_cert" -pubkey -noout | \
        openssl pkey -pubin -outform DER | openssl dgst -sha256)
      if [ "$ca_key_public" != "$ca_cert_public" ]; then
        echo "workspace CA certificate and key do not match" >&2
        exit 1
      fi

      install -d -o root -g nginx -m 0750 "$tls_dir" "$tls_dir/pairs"
      current="$tls_dir/current"
      renew=0
      if [ ! -L "$current" ]; then
        renew=1
      else
        if resolved=$(realpath "$current"); then
          case "$resolved" in
            "$tls_dir/pairs/"*) ;;
            *) renew=1 ;;
          esac
        else
          renew=1
        fi
        if [ "$renew" -eq 0 ] && {
          ! openssl x509 -checkend 2592000 -noout -in "$current/server.pem" >/dev/null 2>&1 ||
          ! openssl verify -CAfile "$ca_cert" "$current/server.pem" >/dev/null 2>&1 ||
          ! openssl x509 -noout -ext subjectAltName -in "$current/server.pem" | grep -Fq "DNS:$wildcard" ||
          ! openssl x509 -noout -ext subjectAltName -in "$current/server.pem" | grep -Fq "DNS:$legacy"
        }; then
          renew=1
        fi
      fi
      if [ "$renew" -eq 0 ]; then
        leaf_key_public=$(openssl pkey -in "$current/server-key.pem" -pubout -outform DER | openssl dgst -sha256)
        leaf_cert_public=$(openssl x509 -in "$current/server.pem" -pubkey -noout | \
          openssl pkey -pubin -outform DER | openssl dgst -sha256)
        [ "$leaf_key_public" = "$leaf_cert_public" ] || renew=1
      fi

      if [ "$renew" -eq 1 ]; then
        build=$(mktemp -d "$tls_dir/.pair.XXXXXX")
        openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
          -out "$build/server-key.pem"
        openssl req -new -key "$build/server-key.pem" -subj "/CN=$canonical" \
          -out "$build/server.csr"
        {
          echo 'basicConstraints=critical,CA:FALSE'
          echo 'keyUsage=critical,digitalSignature'
          echo 'extendedKeyUsage=serverAuth'
          echo "subjectAltName=DNS:$wildcard,DNS:$legacy"
          echo 'subjectKeyIdentifier=hash'
          echo 'authorityKeyIdentifier=keyid,issuer'
        } > "$build/extensions.cnf"
        serial=$(openssl rand -hex 16)
        openssl x509 -req -sha256 -days 397 -in "$build/server.csr" \
          -CA "$ca_cert" -CAkey "$ca_key" -set_serial "0x$serial" \
          -extfile "$build/extensions.cnf" -out "$build/server.pem"
        rm "$build/server.csr" "$build/extensions.cnf"
        chown root:nginx "$build" "$build/server.pem" "$build/server-key.pem"
        chmod 0750 "$build"
        chmod 0644 "$build/server.pem"
        chmod 0640 "$build/server-key.pem"
        openssl verify -CAfile "$ca_cert" "$build/server.pem" >/dev/null
        pair="$tls_dir/pairs/pair-$(date +%s)-$$"
        mv -T "$build" "$pair"
        ln -s "pairs/$(basename "$pair")" "$tls_dir/.current.$$"
        mv -Tf "$tls_dir/.current.$$" "$current"
      fi

      install -d -o root -g root -m 0755 "$(dirname "$public_ca")"
      ca_tmp=$(mktemp "$(dirname "$public_ca")/.ca.XXXXXX")
      install -o root -g root -m 0644 "$ca_cert" "$ca_tmp"
      mv -T "$ca_tmp" "$public_ca"
    '';
  };

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
    imageDigest = "sha256:f8f24d08d7cb4b993e64a52ed87b8eb769788a60df8e921665e817523d0ab945";
    sha256 = "sha256-qEJueaoH2ppxVh0x9LMttYXVSFtajbzHdNVHYL1YFGQ=";
    finalImageName = "ghcr.io/soju06/codex-lb";
    finalImageTag = "1.21.0";
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
    ./kb-staging.nix
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
    confData.sshKeys.builders
    ++ confData.sshKeys.aither.all
    ++ [ ''restrict,from="127.0.0.1,172.16.106.40,::1" ${confData.sshKeys.aither.aitherdev}'' ];

  users.users.aither = {
    isNormalUser = true;
    homeMode = "711";
    linger = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = confData.sshKeys.aither.all;
  };

  users.groups.workspace-portal-proxy.members = [ "nginx" ];
  users.groups.workspace-portal-owner.members = [ "aither" ];

  systemd.tmpfiles.rules = [
    "d ${workspacePortalRouterDir} 2770 aither workspace-portal-proxy -"
  ];

  system.activationScripts.workspacePortalCredentials = {
    deps = [ "users" ];
    text = ''
      ${workspacePortalReconcile}/bin/workspace-portal-substrate-reconcile
    '';
  };

  environment.systemPackages =
    (with pkgs; [
      vim
    ])
    ++ [
      llmAgentsPkgs.codex
      workspacePortalReconcile
    ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  services.postfix.enable = true;

  systemd.services.workspace-portal-certificate-renewal = {
    description = "Renew the workspace portal TLS certificate";
    after = [ "nginx.service" ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };
    script = ''
      ${workspacePortalReconcile}/bin/workspace-portal-substrate-reconcile
      ${pkgs.systemd}/bin/systemctl reload nginx.service
    '';
  };

  systemd.timers.workspace-portal-certificate-renewal = {
    description = "Periodically check the workspace portal TLS certificate";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "6h";
    };
  };

  # Supplementary credentials are fixed when nginx starts. Keep the original
  # trigger stable because this group is unchanged by the substrate split.
  systemd.services.nginx = {
    restartTriggers = [
      (pkgs.writeText "workspace-portal-nginx-group-v1" "workspace-portal-proxy\n")
    ];
    serviceConfig.SupplementaryGroups = [ "workspace-portal-proxy" ];
  };

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
    recommendedTlsSettings = true;
    upstreams.workspace-portal.servers."unix:${workspacePortalRouterSocket}" = { };
    virtualHosts.${workspacePortalWildcard} = {
      serverAliases = [ workspacePortalLegacyHost ];
      forceSSL = true;
      listen = [
        {
          addr = "172.16.106.40";
          port = 80;
        }
        {
          addr = "172.16.106.40";
          port = 443;
          ssl = true;
        }
      ];
      sslCertificate = "${workspacePortalTls}/current/server.pem";
      sslCertificateKey = "${workspacePortalTls}/current/server-key.pem";
      basicAuthFile = workspacePortalAuth;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000" always;
      '';
      locations."/" = {
        proxyPass = "http://workspace-portal";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 1h;
          # Authentication and the application enforce their own tighter
          # limits. Keep this stable substrate ceiling comfortably above them
          # so user-profile updates do not require a NixOS deployment.
          client_max_body_size 16m;
          proxy_set_header Authorization "";
          proxy_hide_header Strict-Transport-Security;
        '';
      };
    };
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

    # Shared nginx HTTP redirects over WireGuard
    iptables -A nixos-fw -p tcp -m tcp --dport 80 -s 172.16.107.0/24 -j ACCEPT

    # development workspace portal
    iptables -A nixos-fw -p tcp -m tcp --dport 443 -s 172.16.107.0/24 -j ACCEPT

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
      image = "ghcr.io/soju06/codex-lb:1.21.0";
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
