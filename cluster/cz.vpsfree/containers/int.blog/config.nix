{ ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ./wordpress.nix
    ./blog-routing.nix
    ./static-blog.nix
    ./legacy-routes.nix
  ];

  system.stateVersion = "26.05";
}
