{
  description = "vpsFree.cz configuration (confctl flake)";

  inputs = {
    confctl.url = "github:vpsfreecz/confctl";

    nixpkgs.follows = "nixpkgsStable";

    nixpkgsStable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgsStable";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    devWorkspace.url = "github:aither64/dev-workspace";

    vpsfreeWeb = {
      url = "github:vpsfreecz/web";
      flake = false;
    };

    vpsfStatus = {
      url = "github:vpsfreecz/vpsf-status";
      inputs.nixpkgs.follows = "nixpkgsStable";
    };

    vpsfreeNotificationTemplates = {
      url = "github:vpsfreecz/vpsfree-notification-templates";
      inputs.vpsadmin.follows = "vpsadminServices";
    };

    nixpkgsStaging.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgsProduction.url = "github:NixOS/nixpkgs/nixos-26.05";

    vpsadminosStaging = {
      url = "github:vpsfreecz/vpsadminos";
      inputs.nixpkgs.follows = "nixpkgsStaging";
      inputs.nixpkgsUnstable.follows = "nixpkgsUnstable";
    };

    vpsadminosOsStaging = {
      url = "github:vpsfreecz/vpsadminos";
      inputs.nixpkgs.follows = "nixpkgsStable";
      inputs.nixpkgsUnstable.follows = "nixpkgsUnstable";
    };

    vpsadminosProduction = {
      url = "github:vpsfreecz/vpsadminos";
      inputs.nixpkgs.follows = "nixpkgsProduction";
      inputs.nixpkgsUnstable.follows = "nixpkgsUnstable";
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
      system = "x86_64-linux";
      devPkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (_final: prev: { ruby = prev.ruby_3_4; })
        ];
      };

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
          vpsadminos = "vpsadminosOsStaging";
        };

        nixos-unstable = {
          nixpkgs = "nixpkgsUnstable";
        };

        nixos-stable = {
          nixpkgs = "nixpkgsStable";
        };

        home-manager = {
          home-manager = "home-manager";
        };

        llm-agents = {
          llm-agents = "llm-agents";
        };

        dev-workspace = {
          devWorkspace = "devWorkspace";
        };

        vpsfree-web = {
          vpsfreeWeb = "vpsfreeWeb";
        };

        vpsf-status = {
          vpsf-status = "vpsfStatus";
        };

        vpsfree-notification-templates = {
          vpsfree-notification-templates = "vpsfreeNotificationTemplates";
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
      devShells.${system}.default = inputs.confctl.lib.mkConfigDevShell {
        inherit system;
        pkgs = devPkgs;
        mode = "tools";
        extraPackages = with devPkgs; [
          bundix
          bundler-audit
        ];
      };
      checks.${system} = {
        vpsf-status-prometheus-rules = import ./tests/prometheus/vpsf-status-rules.nix {
          pkgs = devPkgs;
        };
        vps-autostart-prometheus-rules = import ./tests/prometheus/vps-autostart-rules.nix {
          pkgs = devPkgs;
        };
        process-count-prometheus-rules = import ./tests/prometheus/process-count-rules.nix {
          pkgs = devPkgs;
        };
      };
    };
}
