{ pkgs }:
let
  inherit (pkgs) lib;
  evaluate =
    extra:
    (import (pkgs.path + "/nixos/lib/eval-config.nix") {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/services/monitoring/prometheus/conf-exporters/syslog.nix
        {
          system.stateVersion = "22.05";
          services.prometheus.confExporters.syslog = {
            enable = true;
            package = pkgs.emptyDirectory;
            settings.hosts.node = {
              alias = "node.prg";
              fqdn = "node.prg.vpsfree.cz";
              os = "vpsadminos";
              collectors = [ "vpsadmin_webui" ];
            };
          };
        }
        extra
      ];
    }).config;
  defaults = evaluate { };
  custom = evaluate {
    services.prometheus.confExporters.syslog = {
      user = "custom-exporter";
      group = "custom-exporter";
      stateDir = "/var/lib/custom-exporter";
      listenAddress = "::1";
      port = 19102;
      settings = {
        syslog_pipe = "/run/custom-exporter.pipe";
        pipe_size = 65536;
        max_line_bytes = 1048576;
      };
    };
  };
  disabled = evaluate {
    services.prometheus.confExporters.syslog.enable = lib.mkForce false;
  };
  defaultUnit = defaults.systemd.services.prometheus-syslog-exporter;
  customUnit = custom.systemd.services.prometheus-syslog-exporter;
  defaultSettings = defaults.services.prometheus.confExporters.syslog.settings;
in
assert lib.assertMsg (
  defaultUnit.serviceConfig.Type == "simple"
) "Rust exporter must not require notify";
assert defaultUnit.serviceConfig.Restart == "on-failure";
assert defaultUnit.serviceConfig.RestartSec == 30;
assert !(defaultUnit.serviceConfig ? WatchdogSec);
assert !(defaultUnit.environment ? RACK_ENV);
assert defaultUnit.serviceConfig.User == "syslog-exporter";
assert defaultUnit.serviceConfig.Group == "syslog-exporter";
assert defaultUnit.serviceConfig.WorkingDirectory == "/var/syslog-exporter";
assert lib.hasInfix "/bin/syslog-exporter\" \"--config\"" defaultUnit.serviceConfig.ExecStart;
assert lib.hasSuffix ''"--listen" "0.0.0.0:9102"'' defaultUnit.serviceConfig.ExecStart;
assert lib.hasInfix "syslog-exporter.json" defaultUnit.serviceConfig.ExecStart;
assert !(lib.hasInfix "puma" defaultUnit.serviceConfig.ExecStart);
assert defaultUnit.after == [ "network.target" ];
assert defaultUnit.wantedBy == [ "multi-user.target" ];
assert defaultSettings.syslog_pipe == "/var/log/rsyslog.pipe";
assert
  defaultSettings.hosts.node == {
    alias = "node.prg";
    fqdn = "node.prg.vpsfree.cz";
    os = "vpsadminos";
    collectors = [ "vpsadmin_webui" ];
  };
assert lib.elem "d '/var/syslog-exporter' 0750 syslog-exporter syslog-exporter - -"
  defaults.systemd.tmpfiles.rules;
assert lib.elem "p '/var/log/rsyslog.pipe' 0640 root syslog-exporter - -"
  defaults.systemd.tmpfiles.rules;
assert defaults.users.users.syslog-exporter.isSystemUser;
assert lib.hasSuffix ''"--listen" "[::1]:19102"'' customUnit.serviceConfig.ExecStart;
assert customUnit.serviceConfig.User == "custom-exporter";
assert customUnit.serviceConfig.Group == "custom-exporter";
assert customUnit.serviceConfig.WorkingDirectory == "/var/lib/custom-exporter";
assert lib.elem "p '/run/custom-exporter.pipe' 0640 root custom-exporter - -"
  custom.systemd.tmpfiles.rules;
assert custom.services.prometheus.confExporters.syslog.settings.pipe_size == 65536;
assert custom.services.prometheus.confExporters.syslog.settings.max_line_bytes == 1048576;
assert !(custom.users.users ? custom-exporter);
assert !(disabled.systemd.services ? prometheus-syslog-exporter);
pkgs.runCommand "syslog-exporter-config" { } ''
  touch "$out"
''
