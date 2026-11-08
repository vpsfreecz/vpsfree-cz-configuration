{ ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ./wordpress.nix
    ./blog-routing.nix
    ./static-blog.nix
    ./blog-upload.nix
    ./legacy-routes.nix
  ];

  services.vpsfree-static-blog = {
    enable = true;
    serveStatic = false;
    publication = {
      enable = true;
      secretFile = "/private/blog/deployment-key";
    };
  };

  system.stateVersion = "26.05";
}
