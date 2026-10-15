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
    vendorHash = "sha256-oVS544KEMAE0xRzEwQnxFjU5VELQw8RdLheDNCKWfo4=";
    subPackages = [ "cmd/vpsfree-confctl-ext" ];
    checkPhase = ''
      runHook preCheck
      go test ./...
      go vet ./...
      runHook postCheck
    '';
    postInstall = ''
      install -Dm444 "${configSrc + "/LICENSE.txt"}" "$out/share/doc/vpsfree-confctl-ext/LICENSE.txt"
      install -Dm444 "vendor/github.com/vpsfreecz/confctl/LICENSE.txt" "$out/share/doc/vpsfree-confctl-ext/licenses/confctl/LICENSE.txt"
    '';
  };
  goModuleProxy =
    (package.overrideAttrs (_: {
      proxyVendor = true;
      vendorHash = "sha256-N6gR8gy4/xYcLp6BBHtRS4o1yagHVC1LEIV8ktKLbRc=";
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
