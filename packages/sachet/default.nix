{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "sachet";
  rev = "670ac3c7dfe7aa3152525a12959abe0066d578be";
in buildGoModule rec {
  name = "sachet-${version}";
  # version = lib.substring 0 7 rev;
  version = "vpsfree-0.3.2";

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-BOxdIhJySYywXhOdOzXIvpdugQlIjcpJSBrOcFRmrl8=";
  };

  vendorHash = null;

  tags = [ "release" ];
}
