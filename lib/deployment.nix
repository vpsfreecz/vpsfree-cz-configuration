{ pkgs, lib }:
let
  swpinsFor = name: import ../swpins { inherit name pkgs lib; };

  inConfCtl = (builtins.getEnv "IN_CONFCTL") == "true";
in rec {
  withInfo = { config, info }@arg: if inConfCtl then arg else config;

  osCustom = { name, domain, configFn, ... }@topargs:
    let
      fqdn = "${name}.${domain}";
      swpins = swpinsFor fqdn;
    in withInfo {
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

      info = topargs.info or {
        type = "machine";
        inherit name domain fqdn;
      };
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

        info = {
          type = "node";
          inherit name location domain fqdn;
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
    in withInfo {
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

      info = {
        type = "container";
        inherit name domain fqdn;
      };
    };
}
