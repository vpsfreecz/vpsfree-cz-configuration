{
  fetchgit,
  lib,
  mosh,
}:

let
  rev = "ea326207b4a0a422b79b8b4071633c2e31a2a095";
in
mosh.overrideAttrs (oldAttrs: {
  pname = "mosh-osc-colors";
  version = "${oldAttrs.version}-osc-colors-${builtins.substring 0 7 rev}";

  src = fetchgit {
    url = "https://github.com/aither64/mosh.git";
    inherit rev;
    hash = "sha256-Zp1/i4wo3SnpR669aj4V1TbPmudanh/FA7+RwW8kyd4=";
  };

  patches = lib.filter (
    patch: !(lib.hasInfix "eee1a8cf413051c2a9104e8158e699028ff56b26.patch" (toString patch))
  ) (oldAttrs.patches or [ ]);
})
