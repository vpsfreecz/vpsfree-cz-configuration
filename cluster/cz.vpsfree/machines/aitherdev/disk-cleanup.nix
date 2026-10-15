{ config, pkgs, ... }:
let
  cleanup = pkgs.writeShellScriptBin "nix-store-cleanup" ''
    export PATH=${
      pkgs.lib.makeBinPath [
        config.nix.package
        pkgs.coreutils
      ]
    }
    exec ${pkgs.python3}/bin/python3 ${./nix-store-cleanup.py} "$@"
  '';
  lock = "/run/lock/nix-store-cleanup.lock";
in
{
  environment.systemPackages = [ cleanup ];

  # Back up the former hand-maintained executable before Home Manager links it.
  system.activationScripts.nixStoreCleanupLauncher = {
    deps = [ "users" ];
    text = ''
      launcher=/home/aither/bin/nix-store-cleanup
      if [ -f "$launcher" ] && [ ! -L "$launcher" ]; then
        ${pkgs.coreutils}/bin/mv --backup=numbered -- "$launcher" "$launcher.pre-declarative"
      fi
    '';
  };
  home-manager.users.aither.home.file."bin/nix-store-cleanup".source =
    "${cleanup}/bin/nix-store-cleanup";

  systemd.services.nix-store-cleanup = {
    description = "Retire completed tests and old Nix profile generations";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${cleanup}/bin/nix-store-cleanup --apply --days 7 --keep 2 --gc";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.nix-store-cleanup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30min";
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
      exec ${pkgs.util-linux}/bin/flock --nonblock --conflict-exit-code 0 ${lock} \
        nix-store --store unix:///nix/var/nix/daemon-socket/socket --gc
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
}
