{ buildGoPackage, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "sachet";
  rev = "670ac3c7dfe7aa3152525a12959abe0066d578be";
in buildGoPackage rec {
  name = "sachet-${version}";
  # version = lib.substring 0 7 rev;
  version = "vpsfree-0.3.2";

  goPackagePath = "github.com/messagebird/${repo}";

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-BOxdIhJySYywXhOdOzXIvpdugQlIjcpJSBrOcFRmrl8=";
  };

  tags = [ "release" ];
}
