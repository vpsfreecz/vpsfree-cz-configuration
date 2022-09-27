{ buildGo117Module, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "5b1f3a9360d2c1d87988a1b5e715054f1713d13c";
in buildGo117Module rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-KiQSAjLRBf6XlEeIDsj2lssi2uKeiG0IFTzrPbqrGJY=";
  };

  vendorSha256 = "sha256-BLxOht2O1TO0yWNljulrpXoSGG3JuRw+hL/PXhXSLkk=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
