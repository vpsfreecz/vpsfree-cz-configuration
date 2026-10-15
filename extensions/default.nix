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
    vendorHash = "sha256-vQEri/30XEzl44gN+FQLQtG1VoBbKb4B62d5ZbH332Q=";
    subPackages = [ "cmd/vpsfree-confctl-ext" ];
    checkPhase = ''
      runHook preCheck
      go test ./...
      go vet ./...
      runHook postCheck
    '';
  };
  goModuleProxy =
    (package.overrideAttrs (_: {
      proxyVendor = true;
      vendorHash = "sha256-M1ix9UeBhJcf4a1cem90StSr7UxE5zdIDMPg/dXHh6A=";
    })).goModules;
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
  inherit
    package
    registry
    fixtureRegistryTemplate
    goModuleProxy
    ;
  moduleSource = source + "/extensions";
}
