{ config, lib, ... }:
{
  services.bind = {
    zones = import ./zones.nix { inherit lib; primary = true; };
  };

  systemd.tmpfiles.rules = [
    "d '/var/named' 0550 named named - -"
  ];
}
