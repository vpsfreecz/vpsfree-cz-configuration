{
  config,
  lib,
  confLib,
  ...
}:
{
  services.bind = {
    zones = import ./zones.nix {
      inherit config lib confLib;
      primary = true;
    };
  };
}
