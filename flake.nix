{
  description = "vpsFree.cz configuration (confctl flake)";

  inputs = {
    confctl.url = "github:vpsfreecz/confctl";

    nixpkgs.follows = "nixpkgsStable";

    nixpkgsStable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixpkgsMunin.url = "github:aither64/nixpkgs/25.11-munin-fastcgi";

    nixpkgsStaging.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgsProduction.url = "github:NixOS/nixpkgs/nixos-25.11";

    vpsadminosStaging = {
      url = "github:vpsfreecz/vpsadminos";
      inputs.nixpkgs.follows = "nixpkgsStaging";
    };

    vpsadminosProduction = {
      url = "github:vpsfreecz/vpsadminos";
      inputs.nixpkgs.follows = "nixpkgsProduction";
    };

    vpsadminStaging = {
      url = "github:vpsfreecz/vpsadmin";
      inputs.nixpkgs.follows = "nixpkgsStaging";
      inputs.vpsadminos.follows = "vpsadminosStaging";
    };

    vpsadminProduction = {
      url = "github:vpsfreecz/vpsadmin";
      inputs.nixpkgs.follows = "nixpkgsProduction";
      inputs.vpsadminos.follows = "vpsadminosProduction";
    };

    vpsadminServices = {
      url = "github:vpsfreecz/vpsadmin";
      inputs.nixpkgs.follows = "nixpkgsStable";
      inputs.vpsadminos.follows = "vpsadminosStaging";
    };
  };

  outputs =
    inputs@{ self, confctl, ... }:
    let
      channels = {
        staging = {
          nixpkgs = "nixpkgsStaging";
          vpsadminos = "vpsadminosStaging";
          vpsadmin = "vpsadminStaging";
        };

        production = {
          nixpkgs = "nixpkgsProduction";
          vpsadminos = "vpsadminosProduction";
          vpsadmin = "vpsadminProduction";
        };

        vpsadmin = {
          vpsadmin = "vpsadminServices";
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
      devShells.x86_64-linux.default = inputs.confctl.lib.mkDevShell {
        system = "x86_64-linux";
        pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
      };
    };
}
