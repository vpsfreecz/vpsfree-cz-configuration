{ ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ./wordpress.nix
  ];

  system.stateVersion = "26.05";
}
