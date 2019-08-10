{ pkgs, lib }:
let
  swpinsFor = name: import ../../swpins { inherit name pkgs lib; };

  makeFqdn = { name, location, domain, fqdn }:
    let
      make =
        if location == null then
          "${name}.${domain}"
        else
          "${name}.${location}.${domain}";
    in if fqdn == null then make else fqdn;

  makeModuleArgs =
    { config, swpins, type, spin, name, location ? null, domain, fqdn }@args: {
      inherit swpins;
      deploymentInfo = import ./info.nix (args // { inherit lib; });
    };

  makeImports = spin: extraImports: [
    ../../data
  ] ++ (import ../../modules/module-list.nix).${spin}
    ++ (import ../../cluster/module-list.nix)
    ++ extraImports;
in rec {
  custom = { type, spin, name, location ? null, domain, fqdn ? null, role ? null, config }: {
    inherit type spin name location domain role config;
    fqdn = makeFqdn { inherit name location domain fqdn; };
  };

  nixosMachine = { name, location ? null, domain, fqdn ? null }:
    let
      myFqdn = makeFqdn { inherit name location domain fqdn; };
      swpins = swpinsFor myFqdn;
    in custom {
      type = "machine";
      spin = "nixos";
      inherit name location domain;
      fqdn = myFqdn;
      config =
        { config, pkgs, ... }@args:
        {
          _module.args = makeModuleArgs {
            inherit config swpins;
            type = "machine";
            spin = "nixos";
            inherit name location domain;
            fqdn = myFqdn;
          };

          deployment = {
            nixPath = [
              { prefix = "nixpkgs"; path = swpins.nixpkgs; }
            ];
          };

          imports = makeImports "nixos" [
            (../../cluster + "/${domain}/machines/${lib.optionalString (location != null) location}/${name}.nix")
          ];
        };
    };

  osCustom = { type, name, location ? null, domain, fqdn ? null, role ? null, config }:
    let
      myFqdn = makeFqdn { inherit name location domain fqdn; };
      swpins = swpinsFor myFqdn;
      configFn = config;
    in custom {
      inherit type name location domain role;
      spin = "vpsadminos";
      fqdn = myFqdn;
      config =
        { config, pkgs, ... }@args:
        let
          moduleArgs = makeModuleArgs {
            inherit config swpins type name location domain;
            spin = "vpsadminos";
            fqdn = myFqdn;
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
    };

  osNode = { name, location, domain, fqdn ? null, role }:
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

  osMachine = { name, location ? null, domain, fqdn ? null }:
    osCustom {
      type = "machine";
      inherit name location domain fqdn;
      config =
        { config, pkgs, ... }:
        {
          imports = [
            (../../cluster + "/${domain}/machines/${lib.optionalString (location != null) location}/${name}.nix")
          ];
        };
    };

  osContainer = { name, location ? null, domain, fqdn ? null }:
    let
      myFqdn = makeFqdn { inherit name location domain fqdn; };
      swpins = swpinsFor myFqdn;
    in custom {
      type = "container";
      spin = "nixos";
      inherit name location domain;
      fqdn = myFqdn;
      config =
        { config, pkgs, ... }:
        {
          _module.args = makeModuleArgs {
            inherit config swpins;
            type = "container";
            spin = "nixos";
            inherit name location domain;
            fqdn = myFqdn;
          };

          deployment = {
            nixPath = [
              { prefix = "nixpkgs"; path = swpins.nixpkgs; }
              { prefix = "vpsadminos"; path = swpins.vpsadminos; }
            ];
          };

          imports = makeImports "nixos" [
            (../../cluster + "/${domain}/containers/${lib.optionalString (location != null) location}/${name}.nix")
            ../../profiles/ct.nix
          ];
        };
    };
}
