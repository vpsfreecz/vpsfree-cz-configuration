{
  lib,
  flakeInputs,
  inputsInfo,
  ...
}:
let
  vpsadminInput = inputsInfo.vpsadmin.input;
in
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    flakeInputs.${vpsadminInput}.nixosModules.nixos-modules
    ./settings.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      vpsadminPath = flakeInputs.${vpsadminInput}.outPath;
    })
    flakeInputs.${vpsadminInput}.overlays.default
  ];

  vpsadmin.enableOverlay = lib.mkForce false;
}
