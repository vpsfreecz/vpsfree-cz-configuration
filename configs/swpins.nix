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

  nixpkgsStable = nixpkgsBranch "nixos-25.05";

  vpsadminosStaging = osBranch "staging";

  vpsadminMaster = vpsadminBranch "master";
in
{
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
      nixpkgs = nixpkgsStable;
      vpsadminos = vpsadminosStaging;
      vpsadmin = vpsadminMaster;
    };

    production = {
      nixpkgs = nixpkgsStable;
      vpsadminos = osBranch "staging";
      vpsadmin = vpsadminMaster;
    };

    vpsadmin = {
      vpsadmin = vpsadminMaster;
    };

    os-staging = {
      vpsadminos = osBranch "staging";
    };

    nixos-unstable = {
      nixpkgs = nixpkgsBranch "nixos-unstable";
    };

    nixos-stable = {
      nixpkgs = nixpkgsBranch "nixos-25.05";
    };
  };
}
