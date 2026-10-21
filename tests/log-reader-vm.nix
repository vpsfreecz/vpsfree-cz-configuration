{
  pkgs,
  fixtureModule,
  keys,
}:
pkgs.testers.runNixOSTest {
  name = "log-reader-access";
  nodes.logger =
    { ... }:
    {
      imports = [ fixtureModule ];
      networking.firewall.enable = false;
      users.groups.syslog-exporter = { };
      users.users.syslog-exporter = {
        isSystemUser = true;
        group = "syslog-exporter";
      };
      systemd.tmpfiles.rules = [ "p /var/log/rsyslog.pipe 0640 root syslog-exporter - -" ];
      systemd.services.test-exporter = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = "syslog-exporter";
          Group = "syslog-exporter";
          StateDirectory = "test-exporter";
          # cat exits on FIFO EOF when rsyslog closes its writer. Keep the
          # synthetic consumer available across service restarts and rotation.
          Restart = "always";
        };
        script = "exec cat /var/log/rsyslog.pipe >> /var/lib/test-exporter/captured";
      };
      systemd.services.syslog.after = [ "test-exporter.service" ];
      # Empty fixture categories must not make force-rotation fail.
      services.logrotate.settings = builtins.listToAttrs (
        map
          (name: {
            inherit name;
            value.missingok = true;
          })
          [
            "nodes"
            "machines"
            "containers"
            "others"
          ]
      );
      services.logrotate.extraArgs = [
        "--force"
        "--state"
        "/var/lib/log-reader-test.state"
      ];
      environment.systemPackages = [
        pkgs.python3
        pkgs.acl
      ];
      environment.etc."test-client-key".source = keys.snakeOilEd25519PrivateKey;
    };
  testScript = builtins.readFile ./log-reader-vm.py;
}
