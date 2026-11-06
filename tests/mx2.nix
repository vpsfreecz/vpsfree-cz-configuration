{ pkgs }:
let
  inherit (pkgs) lib;
  domains = [
    "vpsfree.cz"
    "lists.vpsfree.cz"
    "vpsfree.org"
  ];
  capture = pkgs.writeText "capture-mail.py" ''
    import json
    import pathlib
    import sys
    import uuid

    directory = pathlib.Path("/var/lib/mail-fixture")
    record = {"sender": sys.argv[1], "recipient": sys.argv[2], "message": sys.stdin.read()}
    (directory / (str(uuid.uuid4()) + ".json")).write_text(json.dumps(record))
  '';
  receiver = {
    users.users.capture = {
      isSystemUser = true;
      group = "capture";
    };
    users.groups.capture = { };
    systemd.tmpfiles.rules = [ "d /var/lib/mail-fixture 0775 capture capture -" ];
    networking.firewall.allowedTCPPorts = [ 25 ];
    services.postfix = {
      enable = true;
      settings.master.capture = {
        command = "pipe";
        privileged = true;
        args = [
          "flags=Rq"
          "user=capture"
          "argv=${pkgs.python3}/bin/python3"
          "${capture}"
          ("$" + "{sender}")
          ("$" + "{recipient}")
        ];
      };
    };
  };
  network = v4: v6: {
    networking.interfaces.eth1 = {
      ipv4.addresses = lib.mkOverride 20 [
        {
          address = v4;
          prefixLength = 24;
        }
      ];
      ipv6.addresses = lib.mkOverride 20 [
        {
          address = v6;
          prefixLength = 64;
        }
      ];
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "mx2";
  globalTimeout = 30 * 60;
  defaults = {
    virtualisation = {
      memorySize = 1024;
      cores = 1;
      restrictNetwork = true;
      vlans = [ 1 ];
    };
    networking = {
      useDHCP = lib.mkForce false;
      defaultGateway = lib.mkForce null;
      defaultGateway6 = lib.mkForce null;
      nameservers = lib.mkForce [ "192.168.1.30" ];
    };
    services.resolved.enable = false;
    environment.systemPackages = [
      pkgs.python3
      pkgs.bind.dnsutils
      pkgs.iproute2
    ];
    system.stateVersion = "25.05";
  };
  nodes = {
    sender = {
      imports = [
        receiver
        (network "192.168.1.10" "fd42:6d78:32::10")
      ];
      # Override the network helper's priority 20 with both intended sources.
      networking.interfaces.eth1.ipv4.addresses = lib.mkOverride 10 [
        {
          address = "192.168.1.10";
          prefixLength = 24;
        }
        {
          address = "192.168.1.11";
          prefixLength = 24;
        }
      ];
      services.postfix.settings.main = {
        myhostname = "sender.test";
        mydestination = [ "sender.test" ];
        local_transport = "capture";
        local_recipient_maps = [ ];
      };
      environment.etc."mx2-smtp.py".source = ./mx2-smtp.py;
    };
    mx = {
      imports = [
        ../configs/mx2.nix
        (network "192.168.1.20" "fd42:6d78:32::20")
      ];
      # Fixture differences: network/hostname/resolver, short greylist and
      # retry/policy timeouts. Production relay, transport, firewall, trust,
      # filtering, missing milter and persistent paths are imported unchanged.
      services.postgrey.delay = 2;
      services.postfix.settings.main = {
        myhostname = "mx2.vpsfree.cz";
        minimal_backoff_time = "5s";
        maximal_backoff_time = "10s";
        queue_run_delay = "5s";
        smtp_connect_timeout = "5s";
        smtpd_policy_service_timeout = "3s";
        smtpd_policy_service_try_limit = 1;
        smtpd_policy_service_retry_delay = "1s";
      };
    };
    primary = {
      imports = [
        receiver
        (network "192.168.1.30" "fd42:6d78:32::30")
      ];
      networking.firewall = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          no-resolv = true;
          no-poll = true;
          local = "/#/";
          host-record = [
            "sender.test,192.168.1.10,fd42:6d78:32::10"
            "listed.test,192.168.1.11"
            "mx2.vpsfree.cz,192.168.1.20,fd42:6d78:32::20"
            "primary.test,192.168.1.30,fd42:6d78:32::30"
            "prasiatko-mail.vpsfree.cz,192.168.1.30,fd42:6d78:32::30"
            "unrelated.test,192.168.1.30"
            "arbitrary.vpsfree.cz,192.168.1.30"
            "11.1.168.192.zen.spamhaus.org,127.0.0.2"
          ];
          mx-host = map (d: "${d},prasiatko-mail.vpsfree.cz,10") domains ++ [ "sender.test,sender.test,10" ];
          log-queries = true;
        };
      };
      systemd.services.fixture-certificate = {
        wantedBy = [ "multi-user.target" ];
        before = [ "postfix.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
            -subj /CN=primary.test -days 2 \
            -keyout /var/lib/mail-fixture/tls.key -out /var/lib/mail-fixture/tls.crt
        '';
      };
      services.postfix = {
        transport = lib.concatMapStrings (d: "${d} capture:\n") domains;
        settings.main = {
          myhostname = "primary.test";
          mydestination = [ ];
          relay_domains = domains;
          relay_recipient_maps = [ ];
          message_size_limit = 104857600;
          smtpd_recipient_restrictions = [
            "check_recipient_access hash:/var/lib/postfix/fixture-recipients"
          ];
          smtpd_tls_security_level = "may";
          smtpd_tls_chain_files = [
            "/var/lib/mail-fixture/tls.key"
            "/var/lib/mail-fixture/tls.crt"
          ];
          smtpd_tls_loglevel = 1;
          smtpd_tls_received_header = true;
        };
      };
    };
  };
  testScript = builtins.readFile ./mx2.py;
}
