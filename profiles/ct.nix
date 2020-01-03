{ config, ... }:
{
  imports = [
    <nixpkgs/nixos/modules/virtualisation/container-config.nix>
    <vpsadminos/os/lib/nixos-container/build.nix>
    <vpsadminos/os/lib/nixos-container/networking.nix>
  ];

  services.resolved.enable = false;

  systemd.extraConfig = ''
    DefaultTimeoutStartSec=900s
  '';
  systemd.services.systemd-udev-trigger.enable = false;
}
