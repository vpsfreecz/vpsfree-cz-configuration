{ config, ... }:
let
  nixpkgsBranch = branch: {
    type = "git-rev";

    git-rev = {
      url = "https://github.com/NixOS/nixpkgs";
      update.ref = "refs/heads/${branch}";
    };
  };

  osBranch = branch: {
    type = "git-rev";

    git-rev = {
      url = "https://github.com/vpsfreecz/vpsadminos";
      update.ref = "refs/heads/${branch}";
    };
  };

  vpsadminBranch = branch: {
    type = "git-rev";

    git-rev = {
      url = "https://github.com/vpsfreecz/vpsadmin";
      update.ref = "refs/heads/${branch}";
    };
  };

  nixpkgsUnstable = nixpkgsBranch "nixos-unstable";

  nixpkgsStable = nixpkgsBranch "nixos-21.05";

  vpsadminosMaster = osBranch "master";

  vpsadminosStaging = osBranch "staging";

  vpsadminosProd21_09 = osBranch "prod-21.09";

  vpsadminMaster = vpsadminBranch "master";
in {
  confctl.swpins.core.pins = {
    nixpkgs = {
      type = "git-rev";
      git-rev = {
        url = "https://github.com/NixOS/nixpkgs";
        update.ref = "refs/heads/nixos-unstable";
        update.auto = false;
      };
    };
  };

  confctl.swpins.channels = {
    staging = {
      nixpkgs = nixpkgsUnstable;
      vpsadminos = vpsadminosStaging;
      vpsadmin = vpsadminMaster;
    };

    prod21_09 = {
      nixpkgs = nixpkgsStable;
      vpsadminos = vpsadminosProd21_09;
      vpsadmin = vpsadminMaster;
    };

    vpsadmin = {
      vpsadmin = vpsadminMaster;
    };

    os-staging = { vpsadminos = osBranch "staging"; };

    os-runtime-deps = { vpsadminos-runtime-deps = osBranch "osctl-env-exec"; };

    nixos-unstable = { nixpkgs = nixpkgsBranch "nixos-unstable"; };

    nixos-stable = { nixpkgs = nixpkgsBranch "nixos-21.05"; };

    "nixos-20.09" = { nixpkgs = nixpkgsBranch "nixos-20.09"; };

    "nixos-19.03" = { nixpkgs = nixpkgsBranch "nixos-19.03"; };
  };
}
