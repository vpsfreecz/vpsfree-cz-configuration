{ config, ... }:
{
  imports = [
    <vpsadminos/os/lib/nixos-container/vpsadminos.nix>
  ];

  services.resolved.enable = false;

  systemd.extraConfig = ''
    DefaultTimeoutStartSec=900s
  '';

  security.acme = {
    acceptTerms = true;
    defaults.email = "podpora@vpsfree.cz";
  };
}
