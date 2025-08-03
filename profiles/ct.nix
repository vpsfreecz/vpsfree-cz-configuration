{ config, ... }:
{
  imports = [
    <vpsadminos/os/lib/nixos-container/stable/vpsadminos.nix>
  ];

  networking.useDHCP = false;

  services.resolved.enable = false;

  systemd.extraConfig = ''
    DefaultTimeoutStartSec=900s
  '';

  security.acme = {
    acceptTerms = true;
    defaults.email = "podpora@vpsfree.cz";

    # NixOS >=24.05 set the default to a LE URL, which had the side effect
    # of changing hash that identifies LE accounts. While it's not an issue
    # for us, let's not create new accounts unnecessarily.
    # See: https://github.com/NixOS/nixpkgs/pull/317257
    defaults.server = null;
  };
}
