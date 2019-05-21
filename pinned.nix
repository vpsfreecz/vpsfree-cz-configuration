{ lib, pkgs, ... }:
with builtins;
rec {
  # repoName=nixpkgs rev=xyz; nix-prefetch-url --unpack "https://github.com/vpsfreecz/${repoName}/archive/${rev}.tar.gz"
  fetchVpsFreeRepo = repoName: spec: with spec; builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/${repoName}/archive/${rev}.tar.gz";
    sha256 = hash;
  };

  vpsadminSpec = {
     rev = "45cf09df192e67fd4ea5d9611114de75e3f924da";
     hash = "0ffibnbkf4qq5b1kpf9yn1i0w3gggnd4bl7kl9z7i3qzivjsk5nh";
  };

  vpsadminosSpec = {
    rev = "2b6d530d55cce9ed04d4bedd7362123b6f9c11e2";
    hash = "09fv65l49acnbw61wllc892r60gf736dj2wz4w5mwsdkmrfzw7yn";
  };

  nixpkgsVpsFreeSpec = {
    rev = "bd504d2442e406018592ad64030d73cec7bd36c1";
    hash = "02nsp9g1rgalmpv3bmmr38snlr0pznk4b6glm59ssc9m0cwlkdfg";
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
        modules = modules;
        inherit vpsadmin;
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
