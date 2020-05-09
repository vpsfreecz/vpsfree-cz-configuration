{ name, pkgs, lib }:
let
  json = builtins.readFile (./files + "/${name}.json");

  sources = builtins.fromJSON json;

  swpins = lib.mapAttrs (k: v: swpin v) sources;

  swpin = { type, options, handler ? null, ... }:
    let
      realHandler = if handler == null then type else handler;
    in
      handlers.${realHandler} options;

  handlers = rec {
    git = opts:
      let
        filter = lib.filterAttrs (k: v: builtins.elem k [
          "url" "rev" "sha256" "fetchSubmodules"
        ]);
      in pkgs.fetchgit (filter opts);

    vpsadminos = opts:
      let
        repo = git opts;
        shortRev = lib.substring 0 7 (opts.rev);
      in
        pkgs.runCommand "os-version-suffix" {} ''
          cp -a ${repo} $out
          chmod 700 $out
          echo "${shortRev}" > $out/.git-revision
          echo ".git.${shortRev}" > $out/.version-suffix
        '';
  };
in swpins
