{
  description = "vpsFree.cz configuration (confctl flake)";

  inputs = {
    confctl.url = "github:vpsfreecz/confctl/2026-02-15-flakes";

    nixpkgs.follows = "nixpkgsCore";
    nixpkgsCore.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgsStable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixpkgsMunin.url = "github:aither64/nixpkgs/25.11-munin-fastcgi";

    vpsadminosStaging.url = "github:vpsfreecz/vpsadminos/2026-02-19-flakes";
    vpsadminosProduction.url = "github:vpsfreecz/vpsadminos/2026-02-19-flakes";

    vpsadminStaging = {
      url = "github:vpsfreecz/vpsadmin/2026-02-19-flakes";
      inputs.vpsadminos.follows = "vpsadminosStaging";
    };

    vpsadminProduction = {
      url = "github:vpsfreecz/vpsadmin/2026-02-19-flakes";
      inputs.vpsadminos.follows = "vpsadminosProduction";
    };
  };

  outputs =
    inputs@{ self, confctl, ... }:
    let
      channels = {
        staging = {
          nixpkgs = "nixpkgsStable";
          vpsadminos = "vpsadminosStaging";
          vpsadmin = "vpsadminStaging";
        };

        production = {
          nixpkgs = "nixpkgsStable";
          vpsadminos = "vpsadminosProduction";
          vpsadmin = "vpsadminProduction";
        };

        vpsadmin = {
          vpsadmin = "vpsadminStaging";
        };

        os-staging = {
          vpsadminos = "vpsadminosStaging";
        };

        nixos-unstable = {
          nixpkgs = "nixpkgsUnstable";
        };

        nixos-stable = {
          nixpkgs = "nixpkgsStable";
        };
      };

      confctlOutputs = confctl.lib.mkConfctlOutputs {
        confDir = ./.;
        inherit inputs channels;
      };
    in
    {
      confctl = confctlOutputs // {
        settings = confctlOutputs.settings // {
          nix = confctlOutputs.settings.nix // {
            impureEval = true;
          };
        };
      };
    };
}
