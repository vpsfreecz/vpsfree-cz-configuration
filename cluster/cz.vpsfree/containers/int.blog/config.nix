{ config, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ./blog-routing.nix
    ./static-blog.nix
    ./blog-upload.nix
    ./legacy-routes.nix
  ];

  services.vpsfree-static-blog = {
    enable = true;
    publication = {
      enable = true;
      secretFile = "/private/blog/deployment-key";
    };
  };

  # Keep ownership of retained recovery data without enabling the old services.
  users.users = {
    wordpress = {
      group = config.services.nginx.group;
      isSystemUser = true;
    };
    mysql = {
      description = "MySQL server user";
      group = "mysql";
      uid = config.ids.uids.mysql;
    };
  };
  users.groups.mysql.gid = config.ids.gids.mysql;

  system.stateVersion = "26.05";
}
