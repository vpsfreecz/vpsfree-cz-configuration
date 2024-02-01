{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "ccb16f0cd90520130e0942e99245207494d28659";
in buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-4vVvcciRq8MCjhMSucpn4td/mlkrrZ8dduh4BL7dQj4=";
  };

  vendorHash = "sha256-A6qHt0GeNXHsUQ2NF5JIQ3O8bvCi6JTwMOfC8TL07PY=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
