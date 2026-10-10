{ pkgs, configSrc }:
let
  spec = import (configSrc + "/extensions/registry.nix");
  sourceRoot = toString configSrc;
  source = builtins.path {
    name = "vpsfree-confctl-extension-source";
    path = configSrc;
    filter =
      path: type:
      let
        relative = pkgs.lib.removePrefix (sourceRoot + "/") (toString path);
      in
      if type == "directory" then
        toString path == sourceRoot
        || pkgs.lib.any (file: pkgs.lib.hasPrefix (relative + "/") file) spec.boundSourcePaths
      else
        type == "regular" && builtins.elem relative spec.boundSourcePaths;
  };
  package = pkgs.buildGoModule {
    pname = "vpsfree-confctl-ext";
    version = "0.1.0";
    src = source;
    modRoot = "extensions";
    vendorHash = "sha256-MpAABlGxZ0PcTpdiKVAwcrmfi+367zuuu3WH5ipsg/4=";
    subPackages = [ "cmd/vpsfree-confctl-ext" ];
    checkPhase = ''
      runHook preCheck
      go test ./...
      go vet ./...
      runHook postCheck
    '';
  };
  registry = pkgs.writeText "confctl-extension-registry.json" (
    builtins.toJSON {
      schema = 1;
      bound_sources = map (path: {
        inherit path;
        sha256 = builtins.hashFile "sha256" (source + "/${path}");
      }) spec.boundSourcePaths;
      extensions = spec.declarations "${package}/bin/vpsfree-confctl-ext";
    }
  );
  fixtureRegistryTemplate = pkgs.writeText "confctl-extension-fixture-template.json" (
    builtins.toJSON {
      schema = 1;
      bound_sources = [ ];
      extensions = spec.declarations "@SITE@/bin/vpsfree-confctl-ext";
    }
  );
in
{
  inherit package registry fixtureRegistryTemplate;
}
