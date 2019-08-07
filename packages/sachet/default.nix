{ buildGoPackage, fetchFromGitHub, stdenv }:
let
  owner = "messagebird";
  repo = "sachet";
  rev = "01cbd6f1ef9a2b80feae8c75c78e5cc9a78929c6";
in buildGoPackage rec {
  name = "sachet-${version}";
  version = stdenv.lib.substring 0 7 rev;

  goPackagePath = "github.com/${owner}/${repo}";

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "03nm59j66dzc6b3c484v400kgnrjsglv0lksp3i9q2jp0ppyc9zx";
  };

  goDeps = ./deps.nix;

  buildFlags = "--tags release";
}
