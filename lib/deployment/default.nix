{ pkgs, lib, findConfig }:
let
  swpinsFor = name: import ../../swpins { inherit name pkgs lib; };

  makeModuleArgs =
    { config, swpins, type, spin, name, location ? null, domain, fqdn }@args: {
      inherit swpins;
      deploymentInfo = import ./info.nix (args // { inherit lib findConfig; });
    };

  makeImports = spin: extraImports: [
    ../../data
  ] ++ (import ../../modules/module-list.nix).${spin}
    ++ (import ../../cluster/module-list.nix)
    ++ extraImports;
in rec {
  nixosMachine = { name, location ? null, domain, fqdn }:
    let
      swpins = swpinsFor fqdn;
    in
      { config, pkgs, ... }@args:
      {
        _module.args = makeModuleArgs {
          inherit config swpins;
          type = "machine";
          spin = "nixos";
          inherit name location domain;
          fqdn = fqdn;
        };

        deployment = {
          nixPath = [
            { prefix = "nixpkgs"; path = swpins.nixpkgs; }
          ];
        };

        imports = makeImports "nixos" [
          (../../cluster + "/${domain}/machines/${lib.optionalString (location != null) location}/${name}/config.nix")
        ];
      };

  osCustom = { type, name, location ? null, domain, fqdn, role ? null, config }:
    let
      swpins = swpinsFor fqdn;
      configFn = config;
    in
      { config, pkgs, ... }@args:
      let
        moduleArgs = makeModuleArgs {
          inherit config swpins type name location domain;
          spin = "vpsadminos";
          fqdn = fqdn;
        };
      in {
        _module.args = moduleArgs;

        deployment = {
          nixPath = [
            { prefix = "nixpkgs"; path = swpins.nixpkgs; }
            { prefix = "vpsadminos"; path = swpins.vpsadminos; }
          ];
          importPath = "${swpins.vpsadminos}/os/default.nix";
        };

        imports = makeImports "vpsadminos" [
          (configFn (args // moduleArgs))
        ];
      };

  osNode = { name, location, domain, fqdn, role }:
    osCustom {
      type = "node";
      inherit name location domain fqdn role;
      config =
        { config, pkgs, swpins, ... }:
        {
          imports = [
            (../../cluster + "/${domain}/nodes/${location}/${name}/config.nix")
          ];

          nixpkgs.overlays = [
            (import "${swpins.vpsadminos}/os/overlays/vpsadmin.nix" swpins.vpsadmin)
          ];
        };
    };

  osMachine = { name, location ? null, domain, fqdn }:
    osCustom {
      type = "machine";
      inherit name location domain fqdn;
      config =
        { config, pkgs, ... }:
        {
          imports = [
            (../../cluster + "/${domain}/machines/${lib.optionalString (location != null) location}/${name}/config.nix")
          ];
        };
    };

  osContainer = { name, location ? null, domain, fqdn }:
    let
      swpins = swpinsFor fqdn;
    in
      { config, pkgs, ... }:
      {
        _module.args = makeModuleArgs {
          inherit config swpins;
          type = "container";
          spin = "nixos";
          inherit name location domain fqdn;
        };

        deployment = {
          nixPath = [
            { prefix = "nixpkgs"; path = swpins.nixpkgs; }
            { prefix = "vpsadminos"; path = swpins.vpsadminos; }
          ];
        };

        imports = makeImports "nixos" [
          (../../cluster + "/${domain}/containers/${lib.optionalString (location != null) location}/${name}/config.nix")
          ../../profiles/ct.nix
        ];
      };
}
