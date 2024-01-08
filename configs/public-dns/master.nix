{ config, lib, ... }:
{
  imports = [
    ./shared.nix
  ];

  services.bind = {
    zones = import ./zones.nix { inherit lib; master = true; };
  };

  systemd.tmpfiles.rules = [
    "d '/var/named' 0550 named named - -"
  ];
}
