{ config, lib, pkgs, ...}:
{
  networking.dhcp = true;
  networking.bird.enable = true;

  # XXX: include devel keys for now
  users.users.root.openssh.authorizedKeys.keys = with import ../ssh-keys.nix; [ aither snajpa snajpa_devel srk srk_devel ];

  vpsadminos.nix = true;
  environment.systemPackages = with pkgs; [
    nvi
    screen
    ipmicfg
  ];

  # to be able to include ipmicfg
  nixpkgs.config.allowUnfree = true;
}
