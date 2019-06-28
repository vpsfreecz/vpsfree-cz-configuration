{ lib, pkgs, ... }:
with builtins;
rec {
  # repoName=nixpkgs rev=xyz; nix-prefetch-url --unpack "https://github.com/vpsfreecz/${repoName}/archive/${rev}.tar.gz"
  fetchVpsFreeRepo = repoName: spec: with spec; builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/${repoName}/archive/${rev}.tar.gz";
    sha256 = hash;
  };

  vpsadminSpec = {
     rev = "02e2b2144a44ff7849b1b700c5711e107d3eae52";
     hash = "16carxp4mlpywsqvcz0khp1lm5krjvgri7m03d89652zrmfnng0y";
  };

  vpsadminosSpec = {
    rev = "6fe4d78112dcd9c193a65a68e58f38dbccf275a1";
    hash = "161z43x49d2zwqgnf2zpp6rgsyfi7ayqh6qq77k1s5jvwbndm0v8";
  };

  nixpkgsVpsFreeSpec = {
    rev = "67cca52fd99815e96dc5421282529e9707d88654";
    hash = "1hqmmih5ingj3aajgdqm7rf5m0z3jcgdg7xskwh1x7bndkn8i6h4";
  };

  buildVpsFreeTemplatesSpec = {
    rev = "f5829847c8ee1666481eb8a64df61f3018635ec7";
    hash = "1r8b3wyn4ggw1skdalib6i4c4i0cwmbr828qm4msx7c0j76910z4";
  };

  fetchVpsadmin = spec: fetchVpsFreeRepo "vpsadmin" spec;
  fetchVpsadminos = spec:
    let
      repo = fetchVpsFreeRepo "vpsadminos" spec;
      shortRev = lib.substring 0 7 (spec.rev);
    in
      pkgs.runCommand "os-version-suffix" {} ''
        cp -a ${repo} $out
        chmod 700 $out
        echo "${shortRev}" > $out/.git-revision
        echo ".tar.${shortRev}" > $out/.version-suffix
      '';
  fetchNixpkgsVpsFree = spec: fetchVpsFreeRepo "nixpkgs" spec;
  fetchBuildVpsFreeTemplates = spec: fetchVpsFreeRepo "build-vpsfree-templates" spec;

  vpsadminSrc = fetchVpsadmin vpsadminSpec;
  vpsadminosSrc = fetchVpsadminos vpsadminosSpec;
  nixpkgsVpsFreeSrc = fetchNixpkgsVpsFree nixpkgsVpsFreeSpec;
  buildVpsFreeTemplatesSrc = fetchBuildVpsFreeTemplates buildVpsFreeTemplatesSpec;

  nixpkgsVpsFree = import nixpkgsVpsFreeSrc {};

  vpsadminos = {modules ? []}: vpsadminosCustom vpsadminosSpec nixpkgsVpsFreeSpec vpsadminSpec { inherit modules; };

  # allows to build vpsadminos with specific
  # vpsadminos/nixpkgs/vpsadmin sources defined
  # by *Spec record containing rev and hash
  vpsadminosCustom = osSpec: nixpkgsSpec: adminSpec: {modules ? []}:
    let
      os = fetchVpsadminos osSpec;
      nixpkgs = fetchNixpkgsVpsFree nixpkgsSpec;
      vpsadmin = fetchVpsadmin adminSpec;
      # this is fed into scopedImport so vpsadminos sees correct <nixpkgs> everywhere
      overrides = {
        __nixPath = [ { prefix = "nixpkgs"; path = nixpkgs; } ] ++ builtins.nixPath;
        import = fn: scopedImport overrides fn;
        scopedImport = attrs: fn: scopedImport (overrides // attrs) fn;
        builtins = builtins // overrides;
      };
    in
      builtins.scopedImport overrides (os + "/os/") {
        pkgs = nixpkgs;
        system = "x86_64-linux";
        configuration = {};
        inherit modules vpsadmin;
      };
  vpsadminosBuild = {modules ? []}: (vpsadminos { inherit modules; }).config.system.build;

  # Docs support

  # fetch a version from runtime-deps branch
  # which contains bundix generated rubygems
  # required for generating documentation
  vpsadminosDocsDepsSrc = fetchVpsadminos {
    rev = "dc1baa76118db1591574918bb18868a1b937e3c0";
    hash = "0dwagzha2p8ssn691jvz3fqb1by68f117870asc3vwzxqj8zcic8";
  };
  vpsadminosDocsPkgs = import nixpkgsVpsFreeSrc {
    overlays = [
      (import (vpsadminosDocsDepsSrc + "/os/overlays/osctl.nix"))
      (import (vpsadminosDocsDepsSrc + "/os/overlays/ruby.nix"))
    ];
  };

}
