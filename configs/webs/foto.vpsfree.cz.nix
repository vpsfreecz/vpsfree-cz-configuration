{ ... }:
{
  services.nginx.virtualHosts."foto.vpsfree.cz" = {
    enableACME = false;
    forceSSL = false;
    # Keep the gallery unavailable until its PHP runtime can be patched.
    extraConfig = "return 503;";
  };

  users = {
    users.foto = {
      isSystemUser = true;
      group = "vpsfree";
      description = "vpsfree photogallery";
    };

    groups.foto = { };
  };
}
