{ ... }:
let
  source = builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/vpsfree-foto/archive/27f72f12b6bdf5ffff2b13afa23bc47930281e63.tar.gz";
    sha256 = "sha256-i9giqvxb5OfYx3ucbRwRMdkEm2rfxbZF4FwzINn9VIY=";
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
