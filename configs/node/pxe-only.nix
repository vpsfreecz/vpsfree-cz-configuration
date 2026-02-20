# This config is imported ONLY when building node image for PXE
{
  lib,
  config,
  pkgs,
  confMachine,
  pins,
  pinsInfo,
  ...
}:
let
  kernels = import ./kernels.nix {
    inherit
      pkgs
      lib
      config
      pins
      ;
  };
in
{
  boot.kernelVersion = kernels.getBootKernelForMachine confMachine.name;

  system.distBuilderCommands =
    let
      json = pkgs.writeText "machine-${config.networking.hostName}.json" (
        builtins.toJSON {
          spin = "vpsadminos";
          fqdn = confMachine.host.fqdn;
          label = confMachine.host.fqdn;
          toplevel = builtins.unsafeDiscardStringContext config.system.build.toplevel;
          kernelParams = config.boot.kernelParams;
          version = config.system.vpsadminos.version;
          revision = config.system.vpsadminos.revision;
          macs = confMachine.netboot.macs;
          pins-info = pinsInfo;
        }
      );
    in
    ''
      cp ${builtins.unsafeDiscardOutputDependency json} $out/machine.json
    '';
}
