{ config, ... }:
let
  nixpkgsBranch = branch: {
    type = "git";

    git = {
      url = "https://github.com/NixOS/nixpkgs";
      update = "refs/heads/${branch}";
    };
  };

  osBranch = branch: {
    type = "git-rev";

    git-rev = {
      url = "https://github.com/vpsfreecz/vpsadminos";
      update = "refs/heads/${branch}";
    };
  };

  vpsadminBranch = branch: {
    type = "git";

    git = {
      url = "https://github.com/vpsfreecz/vpsadmin";
      update = "refs/heads/${branch}";
    };
  };

  nixpkgsUnstable = nixpkgsBranch "nixos-unstable";

  vpsadminosMaster = osBranch "master";

  vpsadminosDevel = osBranch "devel";

  vpsadminMaster = vpsadminBranch "master";

  vpsadminDevel = vpsadminBranch "devel";
in {
  confctl.swpins.channels = {
    production = {
      nixpkgs = nixpkgsUnstable;
      vpsadminos = vpsadminosMaster;
      vpsadmin = vpsadminMaster;
    };

    storage = {
      nixpkgs = nixpkgsUnstable;
      vpsadminos = vpsadminosMaster;
      vpsadmin = vpsadminMaster;
    };

    playground = {
      nixpkgs = nixpkgsUnstable;
      vpsadminos = vpsadminosMaster;
      vpsadmin = vpsadminMaster;
    };

    staging = {
      nixpkgs = nixpkgsUnstable;
      vpsadminos = vpsadminosMaster;
      vpsadmin = vpsadminMaster;
    };

    os-master = { vpsadminos = osBranch "master"; };

    os-devel = { vpsadminos = osBranch "devel"; };

    os-runtime-deps = { vpsadminos-runtime-deps = osBranch "osctl-env-exec"; };

    nixos-unstable = { nixpkgs = nixpkgsBranch "nixos-unstable"; };

    nixos-stable = { nixpkgs = nixpkgsBranch "nixos-20.03"; };

    "nixos-19.03" = { nixpkgs = nixpkgsBranch "nixos-19.03"; };
  };
}
