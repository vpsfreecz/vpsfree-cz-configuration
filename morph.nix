let
  baseSwpins = import ./swpins rec {
    name = "base";
    pkgs = (import <nixpkgs> {});
    lib = pkgs.lib;
  };

  deployments = import ./deployments.nix;

  managedDeployments = builtins.filter (d: d.managed) deployments;

  nameValuePairs = builtins.map (d: {
    name = d.fqdn;
    value = d.build.toplevel;
  }) managedDeployments;

  configs = builtins.listToAttrs nameValuePairs;
in configs // {
  network =  {
    pkgs = import baseSwpins.nixpkgs {};
    description = "vpsf hosts";
  };
}
