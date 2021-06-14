{ buildGoPackage, fetchFromGitHub, lib }:
let
  owner = "messagebird";
  repo = "sachet";
  rev = "43e67bdffd9de9229c844f3496bd448a7dfebe87";
in buildGoPackage rec {
  name = "sachet-${version}";
  # version = lib.substring 0 7 rev;
  version = "0.2.4";

  goPackagePath = "github.com/${owner}/${repo}";

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256:10dxlw0n2b742xsdg1sc8wxy4bjscs897lwfkdzxw18csqm1hffi";
  };

  buildFlags = "--tags release";
}
