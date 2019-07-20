{ pkgs, lib }:
let
  swpinsFor = name: import ../swpins { inherit name pkgs lib; };

  makeFqdn = { name, location, domain, fqdn }:
    let
      make =
        if location == null then
          "${name}.${domain}"
        else
          "${name}.${location}.${domain}";
    in if fqdn == null then make else fqdn;
in rec {
  custom = { type, name, location ? null, domain, fqdn ? null, config }: {
    inherit type name location domain config;
    fqdn = makeFqdn { inherit name location domain fqdn; };
  };

  nixosMachine = { name, location ? null, domain, fqdn ? null }:
    let
      myFqdn = makeFqdn { inherit name location domain fqdn; };
      swpins = swpinsFor myFqdn;
    in custom {
      type = "machine";
      inherit name location domain;
      fqdn = myFqdn;
      config =
        { config, pkgs, ... }@args:
        {
          _module.args = { inherit swpins; };

          deployment = {
            nixPath = [
              { prefix = "nixpkgs"; path = swpins.nixpkgs; }
            ];
          };

          imports = [
            (../machines + "/${domain}/${name}.nix")
          ];
        };
    };

  osCustom = { type, name, location ? null, domain, fqdn ? null, config, ... }:
    let
      myFqdn = makeFqdn { inherit name location domain fqdn; };
      swpins = swpinsFor myFqdn;
      configFn = config;
    in custom {
      inherit type name location domain;
      fqdn = myFqdn;
      config =
        { config, pkgs, ... }@args:
        {
          _module.args = { inherit swpins; };

          deployment = {
            nixPath = [
              { prefix = "nixpkgs"; path = swpins.nixpkgs; }
              { prefix = "vpsadminos"; path = swpins.vpsadminos; }
            ];
            importPath = "${swpins.vpsadminos}/os/default.nix";
          };

          imports = [
            (configFn (args // { inherit swpins; }))
          ];
        };
    };

  osNode = { name, location, domain, fqdn ? null }:
    osCustom {
      type = "node";
      inherit name location domain fqdn;
      config =
        { config, pkgs, swpins, ... }:
        {
          imports = [
            (../nodes + "/${domain}/${location}/${name}.nix")
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
            (../machines + "/${domain}/${name}.nix")
          ];
        };
    };

  osContainer = { name, location ? null, domain, fqdn ? null }:
    let
      myFqdn = makeFqdn { inherit name location domain fqdn; };
      swpins = swpinsFor myFqdn;
    in custom {
      type = "container";
      inherit name location domain;
      fqdn = myFqdn;
      config =
        { config, pkgs, ... }:
        {
          _module.args = { inherit swpins; };

          deployment = {
            nixPath = [
              { prefix = "nixpkgs"; path = swpins.nixpkgs; }
              { prefix = "vpsadminos"; path = swpins.vpsadminos; }
            ];
          };

          imports = [
            (../containers + "/${domain}/${name}.nix")
            ../profiles/ct.nix
          ];
        };
    };
}
