{ buildGo117Package, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "sachet";
  rev = "d138f07bba0863fa9ccfbc93327fbd625a1917d3";
in buildGo117Package rec {
  name = "sachet-${version}";
  # version = lib.substring 0 7 rev;
  version = "vpsfree-0.3.2";

  goPackagePath = "github.com/messagebird/${repo}";

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256:1z5rv7c0yrg3kcyzsqkn9da2yw04ms527rsn15x24psp4fzb4h1q";
  };

  buildFlags = "--tags release";
}
