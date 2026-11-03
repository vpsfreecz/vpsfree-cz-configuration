{ ... }:
let
  source = builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/vpsfree-foto/archive/4f604c583ebaa994b818028e26a03dac565a063a.tar.gz";
    sha256 = "sha256-dSfhAHbHUKo2SR0JLmHmY9ot1aGbaseIui3JUOq8AAY=";
  };
in
{
  imports = [ "${source}/nixos/gallery.nix" ];

  services.vpsfreePhotoShow = {
    enable = true;
    # Existing TLS proxy; preserve the backend and original gallery paths.
    trustedProxyAddresses = [ "172.16.9.140" ];
  };

  users.users.foto = {
    group = "vpsfree";
    description = "vpsfree photogallery";
  };
}
