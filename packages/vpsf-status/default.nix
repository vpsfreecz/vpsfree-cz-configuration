{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "adb6bb41896fa19c0f994828106bcff51bef8053";
in buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-iDm8OGQBU9ftGy91jiMtuR13YlPqudXtmS5v5P37N8Y=";
  };

  vendorHash = "sha256-Kyx9MPCjNVERTeKRfMF8EAAlIoengsPtlbf3SQJfng4=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
