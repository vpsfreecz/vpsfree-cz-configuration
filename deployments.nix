let
  baseSwpins = import ./swpins rec {
    name = "base";
    pkgs = (import <nixpkgs> {});
    lib = pkgs.lib;
  };

  deployment = import ./lib/deployment rec {
    pkgs = import baseSwpins.nixpkgs {};
    lib = pkgs.lib;
  };

  domain = "vpsfree.cz";

  nameValuePairs = list: map (v: { name = v.fqdn; value = v; }) list;

  mkDeployments = list: builtins.listToAttrs (nameValuePairs list);
in mkDeployments [

  ### Nodes
  ## Prague
  # backuper.prg
  (deployment.osNode {
    name = "backuper";
    location = "prg";
    inherit domain;
    role = "storage";
  })

  ## Staging
  # node1.stg
  (deployment.osNode {
    name = "node1";
    location = "stg";
    inherit domain;
    role = "hypervisor";
  })

  # node2.stg
  (deployment.osNode {
    name = "node2";
    location = "stg";
    inherit domain;
    role = "hypervisor";
  })

  ### Support machines
  # build.vpsfree.cz
  (deployment.osMachine {
    name = "build";
    inherit domain;
  })

  # pxe.vpsfree.cz
  (deployment.nixosMachine {
    name = "pxe";
    inherit domain;
  })

  ### Containers
  # www.vpsadminos.org
  (deployment.osContainer {
    name = "www";
    domain = "vpsadminos.org";
  })

  # proxy.prg.vpsfree.cz
  (deployment.osContainer {
    name = "proxy";
    location = "prg";
    inherit domain;
  })

  # log.vpsfree.cz
  (deployment.osContainer {
    name = "log";
    inherit domain;
  })

  # mon.int.prg.vpsfree.cz
  (deployment.osContainer {
    name = "mon.int";
    location = "prg";
    inherit domain;
  })

  # alerts.int.prg.vpsfree.cz
  (deployment.osContainer {
    name = "alerts.int";
    location = "prg";
    inherit domain;
  })
]
