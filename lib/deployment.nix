{ pkgs, lib }:
let
  swpinsFor = name: import ../swpins { inherit name pkgs lib; };
in rec {
  osCustom = { name, domain, configFn }:
    let
      fqdn = "${name}.${domain}";
      swpins = swpinsFor fqdn;
    in
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

  osNode = { name, location, domain }:
    let
      fqdn = "${name}.${location}.${domain}";
    in
      osCustom {
        name = "${name}.${location}";
        inherit domain;
        configFn =
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

  osMachine = { name, domain }:
    osCustom {
      inherit name domain;
      configFn =
        { config, pkgs, ... }:
        {
          imports = [
            (../machines + "/${domain}/${name}.nix")
          ];
        };
    };

  osContainer = { name, domain }:
    let
      fqdn = "${name}.${domain}";
      swpins = swpinsFor fqdn;
    in
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
}
