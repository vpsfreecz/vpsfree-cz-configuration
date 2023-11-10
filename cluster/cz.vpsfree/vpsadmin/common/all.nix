{ config, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    <vpsadmin/nixos/modules/nixos-modules.nix>
    ./settings.nix
  ];
}
