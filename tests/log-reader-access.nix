{ pkgs, machines }:
let
  inherit (pkgs) lib;
  keys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;
  readerModule = ../cluster/cz.vpsfree/containers/prg/int.log/log-reader.nix;
  confData = {
    sshKeys.aither.aitherdev = keys.snakeOilEd25519PublicKey;
    vpsadmin.networks.management = {
      ipv4 = [ ];
      dhcp = [ ];
    };
  };
  # Reuse the production logger module; omit only site/container dependencies.
  loggerModule =
    { pkgs, lib, ... }:
    builtins.removeAttrs (import ../cluster/cz.vpsfree/containers/prg/int.log/config.nix {
      inherit pkgs lib confData;
      confLib = {
        getAllAddressesOf = _: _: [ ];
        getClusterMachines = _: [ ];
      };
      confMachine = machines."cz.vpsfree/containers/prg/int.log".metaConfig;
      config = {
        cluster = { };
        services.prometheus.confExporters.syslog.settings.syslog_pipe = "/var/log/rsyslog.pipe";
      };
    }) [ "imports" ];
  fixtureModule =
    { lib, ... }:
    {
      imports = [
        loggerModule
        readerModule
      ];
      options.services.prometheus.confExporters.syslog = lib.mkOption {
        type = lib.types.attrs;
      };
      config = {
        _module.args = { inherit confData; };
        services.openssh.enable = true;
        system.stateVersion = "22.05";
      };
    };
  evaluated = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit pkgs;
    system = pkgs.stdenv.hostPlatform.system;
    modules = [ fixtureModule ];
  };
  cfg = evaluated.config;
  reader = cfg.users.users.log-reader;
  rotations = map (name: cfg.services.logrotate.settings.${name}) [
    "nodes"
    "machines"
    "containers"
    "others"
  ];
  syntaxConfig = pkgs.writeText "log-reader-rsyslog.conf" (
    lib.replaceStrings
      [
        "$FileGroup log-readers"
        "$DirGroup log-readers"
        ''fileGroup="log-readers"''
        ''dirGroup="log-readers"''
      ]
      [
        "$FileGroup root"
        "$DirGroup root"
        ''fileGroup="root"''
        ''dirGroup="root"''
      ]
      cfg.services.rsyslogd.defaultConfig
  );
in
assert reader.isNormalUser && reader.group == "log-readers";
assert reader.extraGroups == [ ];
assert reader.openssh.authorizedKeys.keys == [ "restrict ${keys.snakeOilEd25519PublicKey}" ];
assert !(lib.elem "log-reader" cfg.nix.settings.trusted-users);
assert builtins.all (rotation: rotation.create == "0640 root log-readers") rotations;
assert (builtins.head rotations).frequency == "daily" && (builtins.head rotations).rotate == 180;
assert builtins.all (rotation: rotation.frequency == "monthly" && rotation.rotate == 13) (
  builtins.tail rotations
);
assert builtins.all (rotation: rotation.nocompress && rotation.dateext) rotations;
assert lib.hasInfix "AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u"
  cfg.services.openssh.extraConfig;
assert !(lib.hasInfix "from=" (builtins.head reader.openssh.authorizedKeys.keys));
assert lib.hasInfix "$FileCreateMode 0640" cfg.services.rsyslogd.defaultConfig;
assert lib.hasInfix "$DirCreateMode 0750" cfg.services.rsyslogd.defaultConfig;
assert lib.hasInfix "$Umask 0027" cfg.services.rsyslogd.defaultConfig;
assert builtins.all (property: lib.hasInfix property cfg.services.rsyslogd.defaultConfig) [
  ''fileOwner="root"''
  ''fileGroup="log-readers"''
  ''fileCreateMode="0640"''
  ''dirOwner="root"''
  ''dirGroup="log-readers"''
  ''dirCreateMode="0750"''
];
assert lib.hasInfix "call remote-pipe" cfg.services.rsyslogd.defaultConfig;
pkgs.runCommand "log-reader-policy"
  {
    nativeBuildInputs = [
      pkgs.rsyslog
      pkgs.python3
    ];
    passthru.vmTest = import ./log-reader-vm.nix {
      inherit pkgs fixtureModule keys;
    };
  }
  ''
    rsyslogd -N1 -f ${syntaxConfig}
    # NixOS validates the generated logrotate configuration during its build.
    test -s ${cfg.services.logrotate.configFile}
    python3 - <<'PY'
    import ast
    ast.parse(open('${../cluster/cz.vpsfree/containers/prg/int.log/log-reader-reconcile.py}').read())
    PY
    touch "$out"
  ''
