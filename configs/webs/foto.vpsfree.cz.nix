{ ... }:
let
  source = builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/vpsfree-foto/archive/73d88ba4e96cabc1e682279353439c2856217e0d.tar.gz";
    sha256 = "sha256-Dji4dgyDrQ+65HZAti15jUTTdnO4tV5UB8q5x1xPVZE=";
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
