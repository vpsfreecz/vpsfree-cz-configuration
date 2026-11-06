{ ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ./wordpress.nix
    ./static-blog.nix
  ];

  system.stateVersion = "26.05";
}
