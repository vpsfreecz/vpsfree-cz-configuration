{
  config,
  pkgs,
  lib,
  confMachine,
  swpinsInfo,
  ...
}:
let
  machineJson = pkgs.writeText "machine-${config.networking.hostName}.json" (
    builtins.toJSON {
      spin = "nixos";
      fqdn = confMachine.host.fqdn;
      label = confMachine.host.fqdn;
      toplevel = builtins.unsafeDiscardStringContext config.system.build.toplevel;
      version = config.system.nixos.version;
      revision = config.system.nixos.revision;
      macs = confMachine.netboot.macs;
      swpins-info = swpinsInfo;
    }
  );
in
{
  imports = [
    ../../../../environments/base.nix
    <nixpkgs/nixos/modules/installer/netboot/netboot-minimal.nix>
  ];

  system.build.dist = pkgs.symlinkJoin {
    name = "nixos-netboot";
    paths = [
      config.system.build.netbootRamdisk
      config.system.build.kernel
      config.system.build.netbootIpxeScript
    ];
    postBuild = ''
      ln -s ${machineJson} $out/machine.json
    '';
  };

  boot.supportedFilesystems.zfs = true;

  networking.useDHCP = true;

  users.users.root.initialHashedPassword = "";

  system.stateVersion = config.system.nixos.release;
}
