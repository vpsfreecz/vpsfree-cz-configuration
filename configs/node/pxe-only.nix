# This config is imported ONLY when building node image for PXE
{ lib, config, pkgs, confMachine, swpinsInfo, ... }:
let
  kernels = import ./kernels.nix { inherit pkgs lib; };
in {
  boot.kernelVersion = kernels.getBootKernelForMachine confMachine.name;

  system.distBuilderCommands =
    let
      json = pkgs.writeText "machine-${config.networking.hostName}.json" (builtins.toJSON {
        spin = "vpsadminos";
        fqdn = confMachine.host.fqdn;
        label = confMachine.host.fqdn;
        toplevel = builtins.unsafeDiscardStringContext config.system.build.toplevel;
        kernelParams = config.boot.kernelParams;
        macs = confMachine.netboot.macs;
        swpins-info = swpinsInfo;
      });
    in ''
      cp ${json} $out/machine.json
    '';
}
