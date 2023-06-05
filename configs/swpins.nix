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

  nixpkgsStable = nixpkgsBranch "nixos-22.05";

  vpsadminosMaster = osBranch "master";

  vpsadminosStaging = osBranch "staging";

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

    "prod-22.12" = {
      nixpkgs = nixpkgsStable;
      vpsadminos = osBranch "prod-22.12";
      vpsadmin = vpsadminMaster;
    };

    vpsadmin = {
      vpsadmin = vpsadminMaster;
    };

    os-staging = { vpsadminos = osBranch "staging"; };

    nixos-unstable = { nixpkgs = nixpkgsBranch "nixos-unstable"; };

    nixos-stable = { nixpkgs = nixpkgsBranch "nixos-23.05"; };
  };
}
