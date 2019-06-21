{ lib, pkgs, ... }:
with builtins;
rec {
  # repoName=nixpkgs rev=xyz; nix-prefetch-url --unpack "https://github.com/vpsfreecz/${repoName}/archive/${rev}.tar.gz"
  fetchVpsFreeRepo = repoName: spec: with spec; builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/${repoName}/archive/${rev}.tar.gz";
    sha256 = hash;
  };

  vpsadminSpec = {
     rev = "b226bb02714558c614535f599302aad4ab3cb071";
     hash = "0g1gx9fdxkl8hxpl7n19gn863cxf2cs25zj424ndaaqyz5j569xg";
  };

  vpsadminosSpec = {
    rev = "6ed9aec75f0c0455b6b8734b33b882de5aa715b3";
    hash = "0fl19ki4w0hcdi1bmph907l8x68h76kx4kcg7v0gssb1imimz6b7";
  };

  nixpkgsVpsFreeSpec = {
    rev = "b5cf5ff20f92d790b703db00d202a72231943845";
    hash = "1kd2wfvqazbnc18jfscp7vnshwlmjnxcy9d1cmpfwasbz0ks2x4n";
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
